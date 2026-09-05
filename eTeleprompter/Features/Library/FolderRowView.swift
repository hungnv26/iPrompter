import SwiftUI
import SwiftData

/// A single folder row in the sidebar. Shows a plain label normally and an
/// inline-editable text field while the folder is being renamed (WP2).
struct FolderRowView: View {
    @Bindable var folder: Folder
    @Binding var renamingFolderID: UUID?

    @FocusState private var nameFieldFocused: Bool

    private var isRenaming: Bool { renamingFolderID == folder.id }

    var body: some View {
        if isRenaming {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(Color.accentColor)
                TextField("Folder Name", text: $folder.name)
                    .focused($nameFieldFocused)
                    .onSubmit(endRenaming)
                    .onAppear { nameFieldFocused = true }
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused { endRenaming() }
                    }
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
            }
        } else {
            Label(folder.name, systemImage: "folder")
                .lineLimit(1)
        }
    }

    /// Commits the rename: trims whitespace, never leaves an empty name.
    private func endRenaming() {
        let trimmed = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        folder.name = trimmed.isEmpty ? "New Folder" : trimmed
        if renamingFolderID == folder.id {
            renamingFolderID = nil
        }
    }
}
