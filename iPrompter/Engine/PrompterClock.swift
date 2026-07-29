import Foundation

/// Frame-clock abstraction so PrompterEngine is unit-testable without a real
/// display link (WP4). Production impl wraps CADisplayLink (iOS) /
/// CVDisplayLink or CADisplayLink-on-NSScreen (macOS); tests use a manual clock.
///
/// TODO(WP4): define tick callback API and production + test implementations.
protocol PrompterClock: AnyObject {
    func start(_ tick: @escaping (_ deltaTime: TimeInterval) -> Void)
    func stop()
}
