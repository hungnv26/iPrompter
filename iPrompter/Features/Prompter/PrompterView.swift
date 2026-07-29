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

                // QA Bug B (dead touch): the prompter overlay's color/text are
                // pure SwiftUI drawing, so UIKit/AppKit hit-testing sent taps
                // to the hidden NavigationSplitView columns UNDERNEATH the
                // overlay (verified via hitTest: the script list's
                // UICollectionView received them) and the tap-to-reveal
                // gesture never fired. This empty platform view gives the
                // overlay a real hit-testable surface above those columns, so
                // taps route to the prompter — and can no longer leak into
                // the hidden editor/list.
                TouchInterceptor()
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
        // QA Bug A: the viewport frame below proposes a FINITE height, which
        // makes Text truncate with an ellipsis after ~1.5 screens. fixedSize
        // re-proposes nil height so the block always lays out at its full
        // natural height inside the clipped viewport.
        .fixedSize(horizontal: false, vertical: true)
        // QA Bug B (no auto-stop): the WP5 preference-key measurement was
        // never delivered on iPadOS 26 (engine.contentHeight stayed 0, which
        // disables auto-stop, so playback scrolled forever into black).
        // onGeometryChange reports the laid-out height reliably.
        .onGeometryChange(for: Double.self) { proxy in
            proxy.size.height
        } action: { height in
            engine.contentHeight = height
        }
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
            // QA Bug F: a bare-Space menu key equivalent does not fire on
            // macOS (menu clicks and ↑/↓ menu equivalents work — Space is
            // special-cased by AppKit). Space is therefore bound HERE on both
            // platforms; view-level shortcuts are resolved in the responder
            // chain BEFORE menu equivalents, so the menu item (kept for
            // discoverability) can never double-fire.
            Button("Play/Pause") { engine.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
            #if os(iOS)
            // On macOS ↑/↓ are bound by the Playback menu (PrompterCommands),
            // which QA verified working — one binding per key per platform.
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

/// Empty platform view giving the prompter overlay a REAL hit-testable
/// surface (see the QA Bug B comment in `PrompterView.body`). SwiftUI-drawn
/// pixels alone do not participate in UIKit/AppKit hit-testing, so without
/// this, interactions over the overlay fall through to the navigation
/// columns hidden underneath it.
#if os(iOS)
private struct TouchInterceptor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#elseif os(macOS)
private struct TouchInterceptor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
