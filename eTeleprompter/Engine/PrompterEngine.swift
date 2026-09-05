import Foundation
import Observation

/// Transport state of the prompter engine.
enum PrompterState: Equatable {
    case stopped
    case playing
    case paused
}

/// UI-independent scrolling engine (WP4). Views observe `offset`; the engine
/// never imports SwiftUI/UIKit/AppKit. Driven by a PrompterClock tick.
///
/// Semantics (see team/SPEC.md F2):
/// - Opens stopped at offset 0; `play()` starts scrolling, `pause()` retains
///   position, `stop()` resets to the top.
/// - `speed` is the *displayed target* in points/second, clamped 10...300.
///   The *actual* scroll rate (`currentRate`) ramps linearly to the target
///   over 0.3 s on every speed change and on play/pause — no sudden jumps.
/// - When `offset` reaches `contentHeight` the engine auto-stops at the end
///   (offset stays at the end; Stop — or a fresh `play()` — returns to top).
@Observable
final class PrompterEngine {

    // MARK: Constants (SPEC F2)

    /// Allowed speed range in points/second.
    static let speedRange: ClosedRange<Double> = 10...300
    /// Default speed in points/second.
    static let defaultSpeed: Double = 60
    /// Increment used by the −/+ buttons and ↑/↓ keys.
    static let speedStep: Double = 10
    /// Duration of the linear rate ramp applied to every speed change.
    static let rampDuration: TimeInterval = 0.3

    // MARK: Observable state

    /// Current transport state.
    private(set) var state: PrompterState = .stopped

    /// Current scroll offset in points from the top of the text.
    private(set) var offset: Double = 0

    /// The actual, ramped scroll rate in points/second. Lags `speed` by up to
    /// `rampDuration` after any change; 0 while stopped or fully paused.
    private(set) var currentRate: Double = 0

    /// Total scrollable height of the content in points. Set by the view once
    /// text is laid out. `0` means "unknown" and disables auto-stop.
    var contentHeight: Double = 0

    /// Target speed in points/second, clamped to `speedRange`. Displayed
    /// value changes immediately; the actual rate ramps over `rampDuration`.
    var speed: Double {
        get { targetSpeed }
        set {
            let clamped = min(max(newValue, Self.speedRange.lowerBound),
                              Self.speedRange.upperBound)
            guard clamped != targetSpeed else { return }
            targetSpeed = clamped
            if state == .playing {
                beginRamp(to: clamped)
            }
        }
    }

    // MARK: Private state

    private var targetSpeed: Double = PrompterEngine.defaultSpeed

    private var isRamping = false
    private var rampStartRate: Double = 0
    private var rampTargetRate: Double = 0
    private var rampElapsed: TimeInterval = 0

    @ObservationIgnored private let clock: PrompterClock?
    @ObservationIgnored private var clockIsRunning = false

    // MARK: Init

    /// - Parameter clock: frame clock the engine starts/stops as needed.
    ///   Pass `nil` (e.g. in tests) to drive the engine via `tick(deltaTime:)`
    ///   directly.
    init(clock: PrompterClock? = nil) {
        self.clock = clock
    }

    // MARK: Transport

    /// Starts playback, ramping the rate from its current value to `speed`.
    /// Playing from the end of the content restarts from the top.
    func play() {
        guard state != .playing else { return }
        if contentHeight > 0, offset >= contentHeight {
            offset = 0
        }
        state = .playing
        beginRamp(to: targetSpeed)
        startClock()
    }

    /// Pauses playback, ramping the rate down to 0. Position is retained.
    func pause() {
        guard state == .playing else { return }
        state = .paused
        beginRamp(to: 0)
        // Clock keeps ticking until the ramp-down completes.
    }

    /// Space-bar behavior: pause when playing, otherwise (re)start.
    func togglePlayPause() {
        if state == .playing {
            pause()
        } else {
            play()
        }
    }

    /// Stops playback immediately and resets the offset to the top.
    func stop() {
        state = .stopped
        offset = 0
        cancelRamp()
        stopClock()
    }

    // MARK: Speed convenience (−/+ buttons, ↑/↓ keys)

    func increaseSpeed() {
        speed += Self.speedStep
    }

    func decreaseSpeed() {
        speed -= Self.speedStep
    }

    // MARK: Clock tick

    /// Advances the engine by `deltaTime` seconds. Called by the injected
    /// clock in production; tests call it directly or via a manual clock.
    func tick(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        guard state == .playing || isRamping || currentRate != 0 else { return }

        advanceRamp(by: deltaTime)
        offset += currentRate * deltaTime

        if state == .playing, contentHeight > 0, offset >= contentHeight {
            autoStopAtEnd()
            return
        }

        // A pause ramp-down has finished: the clock is no longer needed.
        if state != .playing, !isRamping, currentRate == 0 {
            stopClock()
        }
    }

    // MARK: Ramping

    private func beginRamp(to target: Double) {
        rampStartRate = currentRate
        rampTargetRate = target
        rampElapsed = 0
        isRamping = true
    }

    private func advanceRamp(by deltaTime: TimeInterval) {
        guard isRamping else { return }
        rampElapsed += deltaTime
        let progress = min(rampElapsed / Self.rampDuration, 1)
        currentRate = rampStartRate + (rampTargetRate - rampStartRate) * progress
        if progress >= 1 {
            isRamping = false
        }
    }

    private func cancelRamp() {
        isRamping = false
        currentRate = 0
        rampElapsed = 0
    }

    // MARK: End of content

    private func autoStopAtEnd() {
        offset = contentHeight
        state = .stopped
        cancelRamp()
        stopClock()
    }

    // MARK: Clock management

    private func startClock() {
        guard let clock, !clockIsRunning else { return }
        clockIsRunning = true
        clock.start { [weak self] deltaTime in
            self?.tick(deltaTime: deltaTime)
        }
    }

    private func stopClock() {
        guard let clock, clockIsRunning else { return }
        clockIsRunning = false
        clock.stop()
    }
}
