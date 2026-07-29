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
        // WP5 adds `.commands { ... }` here for macOS menu items (transport, speed, exit).
    }
}
