import SwiftUI
import SwiftData

/// Folders sidebar (WP2): All Scripts + user folders, "+ New Folder",
/// rename/delete via context menu. Deleting a folder never deletes its
/// scripts — the relationship delete rule is `.nullify` (SPEC F1/§4).
struct SidebarView: View {
    @Binding var selection: SidebarItem?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    @State private var renamingFolderID: UUID?
    @State private var folderPendingDelete: Folder?

    var body: some View {
        List(selection: $selection) {
            Label("All Scripts", systemImage: "doc.on.doc")
                .tag(SidebarItem.allScripts)

            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(folders) { folder in
                        FolderRowView(folder: folder, renamingFolderID: $renamingFolderID)
                            .tag(SidebarItem.folder(folder))
                            .contextMenu {
                                Button {
                                    renamingFolderID = folder.id
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    folderPendingDelete = folder
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("eTeleprompter")
        .safeAreaInset(edge: .bottom, alignment: .leading) {
            newFolderButton
        }
        .confirmationDialog(
            "Delete Folder?",
            isPresented: isConfirmingFolderDelete,
            titleVisibility: .visible,
            presenting: folderPendingDelete
        ) { folder in
            Button("Delete Folder", role: .destructive) {
                delete(folder)
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text("\"\(folder.name)\" will be deleted. Its scripts are kept and will appear under All Scripts.")
        }
    }

    private var newFolderButton: some View {
        Button(action: addFolder) {
            Label("New Folder", systemImage: "folder.badge.plus")
                .font(.body.weight(.medium))
        }
        .buttonStyle(.borderless)
        .padding(12)
    }

    private var isConfirmingFolderDelete: Binding<Bool> {
        Binding(
            get: { folderPendingDelete != nil },
            set: { if !$0 { folderPendingDelete = nil } }
        )
    }

    private func addFolder() {
        let folder = Folder()
        modelContext.insert(folder)
        selection = .folder(folder)
        renamingFolderID = folder.id
    }

    private func delete(_ folder: Folder) {
        if renamingFolderID == folder.id {
            renamingFolderID = nil
        }
        if selection == .folder(folder) {
            selection = .allScripts
        }
        // Delete rule is `.nullify`: the folder's scripts survive and revert
        // to "no folder", i.e. they remain visible under All Scripts.
        modelContext.delete(folder)
    }
}
