import Foundation

/// Global reading/mirror/speed settings (WP4). Codable struct persisted as
/// JSON in a single @AppStorage key (see team/PLAN.md). Not per-script.
///
/// TODO(WP4): font family (5 fixed choices), size 20...120 (default 48),
/// line spacing 1.0...2.0 (1.4), margins 0...25% (10%), 8-swatch text/bg
/// colors (white on black), mirrorHorizontal, flipVertical,
/// rotation 0/90/180/270, speed (default 60).
struct ReadingSettings: Codable, Equatable {
    static let `default` = ReadingSettings()
}
