import SwiftUI
import SwiftData

/// Script list (WP2): rows (title, modified date, word count, reading time),
/// search over title+content, "+" create, context menu Duplicate/Move/Delete,
/// sorted by modifiedDate descending.
struct ScriptListView: View {
    var sidebarItem: SidebarItem
    @Binding var selection: Script?

    var body: some View {
        // TODO(WP2): @Query scripts filtered by sidebarItem, .searchable, CRUD.
        ContentUnavailableView("No Scripts", systemImage: "doc.text")
            .navigationTitle("Scripts")
    }
}
