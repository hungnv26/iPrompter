import Foundation
import QuartzCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Production `PrompterClock` (WP5). Wraps a display link so the engine ticks
/// once per frame with the elapsed time since the previous tick.
///
/// - iOS: `CADisplayLink` on the main run loop.
/// - macOS 14: `NSScreen.displayLink(target:selector:)` (also a CADisplayLink);
///   falls back to a 60 Hz timer if no screen is available (headless).
///
/// Lives in Features/Prompter — never in Engine/ — so the engine module stays
/// free of UIKit/AppKit (see team/PLAN.md).
final class DisplayLinkClock: PrompterClock {

    private var tick: ((TimeInterval) -> Void)?
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    #if os(macOS)
    private var fallbackTimer: Timer?
    #endif

    func start(_ tick: @escaping (_ deltaTime: TimeInterval) -> Void) {
        stop()
        self.tick = tick
        lastTimestamp = nil

        #if os(iOS)
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        #elseif os(macOS)
        if let link = NSScreen.main?.displayLink(target: self, selector: #selector(step(_:))) {
            link.add(to: .main, forMode: .common)
            self.link = link
        } else {
            // No screen (headless test environment): approximate 60 Hz.
            let interval = 1.0 / 60.0
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.tick?(interval)
            }
            RunLoop.main.add(timer, forMode: .common)
            fallbackTimer = timer
        }
        #endif
    }

    func stop() {
        link?.invalidate() // Also releases the link's strong reference to self.
        link = nil
        #if os(macOS)
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        #endif
        tick = nil
        lastTimestamp = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let delta: TimeInterval
        if let last = lastTimestamp {
            delta = link.timestamp - last
        } else {
            // First tick after start: use the frame duration (per the
            // PrompterClock contract — no catch-up).
            delta = link.targetTimestamp - link.timestamp
        }
        lastTimestamp = link.timestamp
        tick?(delta)
    }

    deinit {
        stop()
    }
}
