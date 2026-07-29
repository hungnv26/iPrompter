import SwiftUI
import SwiftData

/// Navigation shell: three-column split (folders → scripts → editor) with a
/// full-screen prompter overlay. Owned by scaffold — feature work happens in the
/// child views; do not change child-view signatures without tech-lead sign-off.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var sidebarSelection: SidebarItem? = .allScripts
    @State private var selectedScript: Script?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
        } content: {
            ScriptListView(
                sidebarItem: sidebarSelection ?? .allScripts,
                selection: $selectedScript
            )
        } detail: {
            if let script = selectedScript {
                EditorView(script: script)
            } else {
                ContentUnavailableView("No Script Selected", systemImage: "doc.text")
            }
        }
        .overlay {
            // Cross-platform full-screen presentation (fullScreenCover does not
            // exist on macOS). WP5 implements PrompterView.
            if let script = appState.prompterScript {
                PrompterView(script: script)
                    .ignoresSafeArea()
            }
        }
    }
}
