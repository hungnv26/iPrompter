import SwiftUI
import SwiftData

/// "Move to Folder" submenu for a script's context menu (SPEC F1).
/// Offers "No Folder" (back to All Scripts only) plus every user folder;
/// the script's current location is checkmarked.
struct MoveToFolderMenu: View {
    @Bindable var script: Script
    var folders: [Folder]

    var body: some View {
        Menu {
            moveButton(title: "No Folder", to: nil)
            if !folders.isEmpty {
                Divider()
                ForEach(folders) { folder in
                    moveButton(title: folder.name, to: folder)
                }
            }
        } label: {
            Label("Move to Folder", systemImage: "folder")
        }
    }

    @ViewBuilder
    private func moveButton(title: String, to folder: Folder?) -> some View {
        Button {
            guard script.folder !== folder else { return }
            script.folder = folder
            script.modifiedDate = .now // SPEC §4: folder change updates modifiedDate
        } label: {
            if script.folder === folder {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
