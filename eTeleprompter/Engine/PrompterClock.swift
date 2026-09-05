import Foundation

/// Frame-clock abstraction so PrompterEngine is unit-testable without a real
/// display link (WP4). Production impl wraps CADisplayLink (iOS) /
/// CVDisplayLink or CADisplayLink-on-NSScreen (macOS) — WP5-owned file
/// `Features/Prompter/DisplayLinkClock.swift`. Tests use a manual clock.
///
/// Contract: after `start`, the clock invokes `tick` once per frame with the
/// elapsed seconds since the previous tick (the first tick may use the frame
/// duration). `stop()` ceases ticking; `start` after `stop` resumes with a
/// fresh delta (no catch-up). The engine calls both as needed — a clock may
/// receive `start` only when not running and `stop` only when running.
protocol PrompterClock: AnyObject {
    func start(_ tick: @escaping (_ deltaTime: TimeInterval) -> Void)
    func stop()
}
