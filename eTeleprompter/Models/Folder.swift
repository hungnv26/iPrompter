import Foundation
import SwiftData

/// A flat (non-nesting) folder. Deleting a folder must never delete scripts:
/// the relationship delete rule is `.nullify` (SPEC §4).
@Model
final class Folder {
    var id: UUID
    var name: String

    @Relationship(deleteRule: .nullify, inverse: \Script.folder)
    var scripts: [Script]

    init(name: String = "New Folder") {
        self.id = UUID()
        self.name = name
        self.scripts = []
    }
}
