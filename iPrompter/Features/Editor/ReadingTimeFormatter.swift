import Foundation

/// Formats an estimated reading time as `Xm Ys`, or `Ys` under one minute
/// (SPEC §4: 300 words → `2m 0s`, 45 s → `45s`). Pure and testable per the
/// MVVM conventions in team/PLAN.md.
enum ReadingTimeFormatter {
    static func string(from interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        guard totalSeconds >= 60 else { return "\(totalSeconds)s" }
        return "\(totalSeconds / 60)m \(totalSeconds % 60)s"
    }
}
