import Foundation

/// Finder-style "copy" naming for duplicated scripts (SPEC F1).
///
/// Pure logic, kept out of view bodies per the MVVM conventions in team/PLAN.md.
enum DuplicateNamer {
    /// Returns the first of `"<Base> copy"`, `"<Base> copy 2"`, `"<Base> copy 3"`, …
    /// that does not appear in `existingTitles`.
    ///
    /// If `title` itself already ends in `" copy"` or `" copy N"`, that suffix is
    /// treated as part of the copy numbering (Finder-style), so duplicating
    /// `"Demo copy"` yields `"Demo copy 2"`, not `"Demo copy copy"`.
    static func copyName(for title: String, existingTitles: Set<String>) -> String {
        let base = baseName(of: title)
        var candidate = "\(base) copy"
        var counter = 2
        while existingTitles.contains(candidate) {
            candidate = "\(base) copy \(counter)"
            counter += 1
        }
        return candidate
    }

    /// Strips a trailing `" copy"` or `" copy <digits>"` suffix, if present.
    private static func baseName(of title: String) -> String {
        if title.hasSuffix(" copy") {
            return String(title.dropLast(" copy".count))
        }
        if let range = title.range(of: #" copy \d+$"#, options: .regularExpression) {
            return String(title[..<range.lowerBound])
        }
        return title
    }
}
