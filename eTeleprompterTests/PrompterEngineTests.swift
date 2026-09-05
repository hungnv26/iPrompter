import XCTest
@testable import eTeleprompter

/// Manual clock for tests: records start/stop and advances the engine by
/// fixed deltas, exactly as a display link would.
final class ManualClock: PrompterClock {
    private(set) var isRunning = false
    private var tick: ((TimeInterval) -> Void)?

    func start(_ tick: @escaping (_ deltaTime: TimeInterval) -> Void) {
        self.tick = tick
        isRunning = true
    }

    func stop() {
        isRunning = false
        tick = nil
    }

    /// Delivers `steps` ticks of `deltaTime` seconds each.
    func advance(by deltaTime: TimeInterval, steps: Int = 1) {
        for _ in 0..<steps {
            tick?(deltaTime)
        }
    }
}

/// Unit tests for the UI-independent PrompterEngine (WP4).
///
/// Note on integration: the engine updates `currentRate` first, then
/// integrates `offset += currentRate * dt` — expected offsets below follow
/// that discrete scheme.
final class PrompterEngineTests: XCTestCase {

    // MARK: Initial state

    func testInitialState() {
        let engine = PrompterEngine()
        XCTAssertEqual(engine.state, .stopped)
        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.speed, 60)
        XCTAssertEqual(engine.currentRate, 0)
    }

    // MARK: Speed clamping and stepping

    func testSpeedClampsToRange() {
        let engine = PrompterEngine()
        engine.speed = 5
        XCTAssertEqual(engine.speed, 10)
        engine.speed = 400
        XCTAssertEqual(engine.speed, 300)
        engine.speed = 150
        XCTAssertEqual(engine.speed, 150)
    }

    func testSpeedStepButtonsClampAtBounds() {
        let engine = PrompterEngine()
        engine.speed = 300
        engine.increaseSpeed()
        XCTAssertEqual(engine.speed, 300, "must never exceed 300")

        engine.speed = 10
        engine.decreaseSpeed()
        XCTAssertEqual(engine.speed, 10, "must never go below 10")

        engine.speed = 60
        engine.increaseSpeed()
        XCTAssertEqual(engine.speed, 70)
        engine.decreaseSpeed()
        XCTAssertEqual(engine.speed, 60)
    }

    // MARK: State machine transitions

    func testPlayPauseResumeStopTransitions() {
        let engine = PrompterEngine()

        engine.play()
        XCTAssertEqual(engine.state, .playing)

        engine.pause()
        XCTAssertEqual(engine.state, .paused)

        engine.play() // resume
        XCTAssertEqual(engine.state, .playing)

        engine.stop()
        XCTAssertEqual(engine.state, .stopped)
    }

    func testTogglePlayPause() {
        let engine = PrompterEngine()
        engine.togglePlayPause()
        XCTAssertEqual(engine.state, .playing)
        engine.togglePlayPause()
        XCTAssertEqual(engine.state, .paused)
        engine.togglePlayPause()
        XCTAssertEqual(engine.state, .playing)
    }

    func testPauseWhenNotPlayingDoesNothing() {
        let engine = PrompterEngine()
        engine.pause()
        XCTAssertEqual(engine.state, .stopped)
    }

    func testTickWhileStoppedDoesNotMove() {
        let engine = PrompterEngine()
        engine.tick(deltaTime: 1.0)
        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.currentRate, 0)
    }

    // MARK: Ramp behavior

    func testPlayRampsRateLinearlyOverRampDuration() {
        let engine = PrompterEngine() // target 60

        engine.play()
        XCTAssertEqual(engine.currentRate, 0, "rate ramps; it does not jump")

        engine.tick(deltaTime: 0.15) // halfway through the 0.3 s ramp
        XCTAssertEqual(engine.currentRate, 30, accuracy: 0.001)

        engine.tick(deltaTime: 0.15) // ramp complete
        XCTAssertEqual(engine.currentRate, 60, accuracy: 0.001)

        engine.tick(deltaTime: 1.0) // steady state
        XCTAssertEqual(engine.currentRate, 60, accuracy: 0.001)
    }

    func testSpeedChangeDisplaysImmediatelyButRampsRate() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3) // reach steady 60

        engine.speed = 120
        XCTAssertEqual(engine.speed, 120, "displayed target changes immediately")
        XCTAssertEqual(engine.currentRate, 60, accuracy: 0.001,
                       "actual rate has not jumped")

        engine.tick(deltaTime: 0.15)
        XCTAssertEqual(engine.currentRate, 90, accuracy: 0.001)

        engine.tick(deltaTime: 0.15)
        XCTAssertEqual(engine.currentRate, 120, accuracy: 0.001)
    }

    func testSpeedChangeMidRampRestartsFromCurrentRate() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.15) // mid-ramp: rate 30

        engine.speed = 100 // new ramp starts at 30, not at 0 or 60
        engine.tick(deltaTime: 0.15)
        XCTAssertEqual(engine.currentRate, 65, accuracy: 0.001,
                       "halfway between 30 and 100")
        engine.tick(deltaTime: 0.15)
        XCTAssertEqual(engine.currentRate, 100, accuracy: 0.001)
    }

    func testSpeedChangeWhilePausedDoesNotMoveOrRamp() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 1.0)
        engine.pause()
        engine.tick(deltaTime: 0.3) // ramp-down complete
        let pausedOffset = engine.offset

        engine.speed = 200
        engine.tick(deltaTime: 1.0)
        XCTAssertEqual(engine.offset, pausedOffset, "paused text never moves")
        XCTAssertEqual(engine.currentRate, 0)
    }

    func testOffsetIntegratesRateOverTicks() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3) // ramp: rate hits 60 at tick end → offset 18
        XCTAssertEqual(engine.offset, 18, accuracy: 0.001)

        engine.tick(deltaTime: 1.0) // steady: +60
        XCTAssertEqual(engine.offset, 78, accuracy: 0.001)
    }

    // MARK: Pause / resume semantics

    func testPauseRampsDownAndRetainsPosition() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 0.7) // offset 18 + 42 = 60

        engine.pause()
        XCTAssertEqual(engine.state, .paused)
        XCTAssertEqual(engine.currentRate, 60, accuracy: 0.001,
                       "rate ramps down; it does not jump to 0")

        engine.tick(deltaTime: 0.15) // rate 30 → offset += 4.5
        XCTAssertEqual(engine.currentRate, 30, accuracy: 0.001)

        engine.tick(deltaTime: 0.15) // rate 0
        XCTAssertEqual(engine.currentRate, 0, accuracy: 0.001)
        let restingOffset = engine.offset
        XCTAssertEqual(restingOffset, 64.5, accuracy: 0.001)

        engine.tick(deltaTime: 5.0) // fully paused: no movement
        XCTAssertEqual(engine.offset, restingOffset)
    }

    func testResumeContinuesFromPausedPosition() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 0.7)
        engine.pause()
        engine.tick(deltaTime: 0.3)
        let pausedOffset = engine.offset

        engine.play() // resume
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(engine.offset, pausedOffset, "resume does not reset position")

        engine.tick(deltaTime: 0.3) // ramp back up, moving again
        XCTAssertGreaterThan(engine.offset, pausedOffset)
        XCTAssertEqual(engine.currentRate, 60, accuracy: 0.001)
    }

    // MARK: Stop resets to top

    func testStopResetsOffsetToTop() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 2.0)
        XCTAssertGreaterThan(engine.offset, 0)

        engine.stop()
        XCTAssertEqual(engine.state, .stopped)
        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.currentRate, 0)

        engine.tick(deltaTime: 1.0) // stopped engine ignores ticks
        XCTAssertEqual(engine.offset, 0)
    }

    func testStopWhilePausedResetsToTop() {
        let engine = PrompterEngine()
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 1.0)
        engine.pause()
        engine.stop()
        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.state, .stopped)
        XCTAssertEqual(engine.currentRate, 0)
    }

    // MARK: Auto-stop at end

    func testAutoStopsAtContentEnd() {
        let engine = PrompterEngine()
        engine.contentHeight = 100
        engine.play()
        engine.tick(deltaTime: 0.3) // offset 18

        engine.tick(deltaTime: 2.0) // would reach 138 → clamps to end and stops
        XCTAssertEqual(engine.offset, 100, "offset clamps to the end, not past it")
        XCTAssertEqual(engine.state, .stopped)
        XCTAssertEqual(engine.currentRate, 0)

        engine.tick(deltaTime: 1.0) // no further movement
        XCTAssertEqual(engine.offset, 100)
    }

    func testPlayAfterAutoStopRestartsFromTop() {
        let engine = PrompterEngine()
        engine.contentHeight = 100
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 2.0) // auto-stopped at end

        engine.play()
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(engine.offset, 0, "playing from the end restarts at the top")
    }

    func testZeroContentHeightNeverAutoStops() {
        let engine = PrompterEngine() // contentHeight stays 0 (unknown)
        engine.play()
        engine.tick(deltaTime: 0.3)
        engine.tick(deltaTime: 10.0)
        XCTAssertEqual(engine.state, .playing)
        XCTAssertGreaterThan(engine.offset, 0)
    }

    // MARK: Clock lifecycle

    func testClockStartsOnPlayAndStopsOnStop() {
        let clock = ManualClock()
        let engine = PrompterEngine(clock: clock)
        XCTAssertFalse(clock.isRunning)

        engine.play()
        XCTAssertTrue(clock.isRunning)

        clock.advance(by: 0.1, steps: 5)
        XCTAssertGreaterThan(engine.offset, 0)

        engine.stop()
        XCTAssertFalse(clock.isRunning)
    }

    func testClockKeepsRunningThroughPauseRampThenStops() {
        let clock = ManualClock()
        let engine = PrompterEngine(clock: clock)
        engine.play()
        clock.advance(by: 0.1, steps: 10)

        engine.pause()
        XCTAssertTrue(clock.isRunning, "clock runs until the ramp-down finishes")

        clock.advance(by: 0.1, steps: 2)
        XCTAssertTrue(clock.isRunning)

        clock.advance(by: 0.1, steps: 1) // ramp-down complete at 0.3 s
        XCTAssertFalse(clock.isRunning)

        engine.play()
        XCTAssertTrue(clock.isRunning, "resume restarts the clock")
    }

    func testClockStopsOnAutoStop() {
        let clock = ManualClock()
        let engine = PrompterEngine(clock: clock)
        engine.contentHeight = 30
        engine.play()
        clock.advance(by: 0.1, steps: 30)
        XCTAssertEqual(engine.state, .stopped)
        XCTAssertEqual(engine.offset, 30)
        XCTAssertFalse(clock.isRunning)
    }
}
