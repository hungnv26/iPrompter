import SwiftUI
import Combine

/// Full-screen reading view (WP5): engine-driven scrolling text, mirror
/// transforms on the reading container ONLY, auto-hiding control overlay,
/// settings popover, keyboard Space/↑/↓/Esc.
///
/// Presented by RootView's overlay while `appState.prompterScript` is non-nil;
/// exits by setting it back to nil. Opens paused at the top (SPEC F2).
struct PrompterView: View {
    var script: Script

    @Environment(AppState.self) private var appState

    @State private var engine = PrompterEngine(clock: DisplayLinkClock())
    @State private var settingsStore = SettingsStore()
    @State private var controlsVisible = true
    @State private var showSettings = false
    /// Mutated on every interaction WITHOUT invalidating the view (it is a
    /// class whose changes SwiftUI does not observe) — mouse-move events on
    /// macOS would otherwise re-evaluate the body continuously.
    @State private var interaction = InteractionTracker()

    /// SPEC F3: controls auto-hide after 3 s of inactivity during playback.
    private static let autoHideDelay: TimeInterval = 3
    private let autoHideTick = Timer.publish(every: 0.5, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                settingsStore.settings.backgroundColor.color
                    .ignoresSafeArea()

                readingContainer(size: geometry.size)

                keyboardShortcutButtons

                if controlsVisible {
                    PrompterControlsView(
                        engine: engine,
                        store: settingsStore,
                        showSettings: $showSettings,
                        onExit: exitPrompter
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .contentShape(Rectangle())
        .onTapGesture { registerInteraction() } // Tap anywhere reveals controls (iPad).
        #if os(macOS)
        .onContinuousHover { phase in // Mouse move reveals controls (Mac).
            if case .active = phase { registerInteraction() }
        }
        #endif
        .onPreferenceChange(PrompterTextHeightKey.self) { height in
            engine.contentHeight = height
        }
        .onReceive(autoHideTick) { _ in autoHideIfIdle() }
        .onChange(of: engine.state) { registerInteraction() }
        .onChange(of: engine.speed) {
            // Persist the target speed globally (SPEC F3) and keep the
            // readout visible when speed is changed via keys/menu.
            settingsStore.settings.speed = engine.speed
            registerInteraction()
        }
        .onChange(of: settingsStore.settings) { registerInteraction() }
        .onAppear { engine.speed = settingsStore.settings.speed }
        .onDisappear { engine.stop() }
        .focusedSceneValue(\.prompterEngine, engine)
    }

    // MARK: Reading container (the ONLY thing that gets mirrored)

    private func readingContainer(size: CGSize) -> some View {
        PrompterTextBlock(
            content: script.content,
            settings: settingsStore.settings,
            viewportWidth: size.width
        )
        .equatable() // Text is laid out once; scrolling is translation only.
        .offset(y: -engine.offset)
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .mirrorTransforms(settingsStore.settings)
        .allowsHitTesting(false)
    }

    // MARK: Keyboard (hidden buttons work from iOS 17.0 / macOS 14.0;
    // .onKeyPress would need 17.4 / 14.4 — see team/PLAN.md and DECISIONS.md)

    private var keyboardShortcutButtons: some View {
        Group {
            // Esc exits on both platforms (cancelAction == Escape).
            Button("Exit Prompter", action: exitPrompter)
                .keyboardShortcut(.cancelAction)
            #if os(iOS)
            // On macOS these three keys are bound by the Playback menu
            // (PrompterCommands) instead — one binding per key per platform.
            Button("Play/Pause") { engine.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("Faster") { engine.increaseSpeed() }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("Slower") { engine.decreaseSpeed() }
                .keyboardShortcut(.downArrow, modifiers: [])
            #endif
        }
        .buttonStyle(.plain)
        .labelsHidden()
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: Control-overlay visibility

    private func registerInteraction() {
        interaction.lastInteraction = .now
        if !controlsVisible {
            withAnimation(.easeOut(duration: 0.2)) { controlsVisible = true }
        }
    }

    private func autoHideIfIdle() {
        guard engine.state == .playing,
              controlsVisible,
              !showSettings,
              Date.now.timeIntervalSince(interaction.lastInteraction) >= Self.autoHideDelay
        else { return }
        withAnimation(.easeIn(duration: 0.25)) { controlsVisible = false }
    }

    // MARK: Exit

    private func exitPrompter() {
        engine.stop()
        appState.prompterScript = nil
    }
}

/// Reference-type timestamp holder so interaction tracking never triggers a
/// SwiftUI view invalidation (see `PrompterView.interaction`).
private final class InteractionTracker {
    var lastInteraction: Date = .now
}
