import SwiftUI
import SwiftData

/// Editor (WP3): title field + full-height plain-text editor, auto-save on
/// every keystroke (updates modifiedDate), toolbar with word count, reading
/// time, and a Start Prompter button (sets appState.prompterScript).
struct EditorView: View {
    @Bindable var script: Script
    @Environment(AppState.self) private var appState

    var body: some View {
        // TODO(WP3): TextField(title) + TextEditor(content), toolbar stats,
        // Start Prompter button.
        Text(script.title)
            .navigationTitle(script.title)
    }
}
