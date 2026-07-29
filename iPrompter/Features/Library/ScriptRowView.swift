import SwiftUI

/// A script row: title plus modified date, word count, and estimated
/// reading time (SPEC §5, screen 2).
struct ScriptRowView: View {
    var script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.title.isEmpty ? "Untitled" : script.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(script.modifiedDate, format: .dateTime.day().month().year().hour().minute())
                Text("·")
                Text("\(script.wordCount) words")
                Text("·")
                Text(readingTimeText(script.estimatedReadingTime))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

/// Formats a reading time as "4m 30s", or "45s" under one minute (SPEC §4).
/// File-private on purpose: the Editor feature (WP3) owns the shared
/// formatter file; a private helper avoids a same-module name collision.
private func readingTimeText(_ interval: TimeInterval) -> String {
    let totalSeconds = Int(interval.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
}
