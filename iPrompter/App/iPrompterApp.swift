import SwiftUI
import SwiftData

@main
struct iPrompterApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(for: [Script.self, Folder.self])
        // WP5: macOS "Playback" menu (Play/Pause ⎵, Faster ↑, Slower ↓),
        // enabled only while the prompter is presented. No-op on iOS.
        .commands {
            PrompterCommands()
        }
    }
}
