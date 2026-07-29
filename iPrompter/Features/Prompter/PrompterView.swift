import SwiftUI

/// Full-screen reading view (WP5): engine-driven scrolling text, mirror
/// transforms on the reading container ONLY, auto-hiding control overlay,
/// settings sheet, keyboard shortcuts (Space/↑/↓/Esc).
/// Exit by setting appState.prompterScript = nil.
struct PrompterView: View {
    var script: Script
    @Environment(AppState.self) private var appState

    var body: some View {
        // TODO(WP5): scrolling text + controls. Placeholder exits on tap.
        ZStack {
            Color.black
            Text("Prompter — coming in WP5")
                .foregroundStyle(.white)
        }
        .onTapGesture { appState.prompterScript = nil }
    }
}
