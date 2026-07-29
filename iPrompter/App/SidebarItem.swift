import Foundation

/// Sidebar selection: "All Scripts" or a user folder.
/// Owned by scaffold. Shared by RootView (App) and the Library feature (WP2).
enum SidebarItem: Hashable {
    case allScripts
    case folder(Folder)
}
