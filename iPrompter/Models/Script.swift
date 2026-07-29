import Foundation
import SwiftData

/// A teleprompter script. Owned by scaffold; see team/SPEC.md §4.
@Model
final class Script {
    var id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var folder: Folder?

    init(title: String = "Untitled", content: String = "", folder: Folder? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        let now = Date.now
        self.createdDate = now
        self.modifiedDate = now
        self.folder = folder
    }

    /// Whitespace/newline-separated token count. Computed, never stored (SPEC §4).
    var wordCount: Int {
        content.split(whereSeparator: \.isWhitespace).count
    }

    /// Seconds at 150 wpm. Display as "4m 30s" / "45s" (SPEC §4).
    var estimatedReadingTime: TimeInterval {
        Double(wordCount) / 150.0 * 60.0
    }
}
