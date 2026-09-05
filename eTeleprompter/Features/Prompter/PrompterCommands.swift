import SwiftUI

// MARK: - Focused value plumbing

/// PrompterView publishes its engine via `.focusedSceneValue` so the macOS
/// menu-bar commands below can drive it (approach prescribed by team/PLAN.md).
private struct PrompterEngineFocusedKey: FocusedValueKey {
    typealias Value = PrompterEngine
}

extension FocusedValues {
    var prompterEngine: PrompterEngine? {
        get { self[PrompterEngineFocusedKey.self] }
        set { self[PrompterEngineFocusedKey.self] = newValue }
    }
}

// MARK: - Menu commands (macOS only)

/// "Playback" menu (WP5): Play/Pause Space, Faster ↑, Slower ↓. Items are
/// enabled only while the prompter is presented (engine focused-value non-nil).
///
/// macOS keyboard handling for Space/↑/↓ lives HERE (real menu items, the
/// platform-native mechanism); on iOS the same keys are hidden
/// `.keyboardShortcut` buttons inside PrompterView — keeping each key bound
/// exactly once per platform avoids duplicate key-equivalent conflicts.
struct PrompterCommands: Commands {
    @FocusedValue(\.prompterEngine) private var engine

    var body: some Commands {
        #if os(macOS)
        CommandMenu("Playback") {
            Button(engine?.state == .playing ? "Pause" : "Play") {
                engine?.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(engine == nil)

            Divider()

            Button("Faster") {
                engine?.increaseSpeed()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(engine == nil)

            Button("Slower") {
                engine?.decreaseSpeed()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(engine == nil)
        }
        #else
        EmptyCommands()
        #endif
    }
}
