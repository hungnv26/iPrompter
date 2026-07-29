import SwiftUI
import SwiftData

/// Folders sidebar (WP2): All Scripts + user folders, "+ New Folder",
/// rename/delete via context menu (delete = confirm, scripts survive).
struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        // TODO(WP2): @Query folders, New Folder button, rename/delete.
        List(selection: $selection) {
            Label("All Scripts", systemImage: "doc.on.doc")
                .tag(SidebarItem.allScripts)
        }
        .navigationTitle("iPrompter")
    }
}
