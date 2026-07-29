import Foundation
import Observation

/// UI-independent scrolling engine (WP4). Views observe `offset`; the engine
/// never imports SwiftUI/UIKit/AppKit. Driven by a PrompterClock tick.
///
/// TODO(WP4): state machine (stopped/playing/paused), pts/sec speed 10...300,
/// 0.3 s speed ramp, auto-stop at end. See team/PLAN.md.
@Observable
final class PrompterEngine {
    /// Current scroll offset in points from the top of the text.
    private(set) var offset: Double = 0

    /// Target speed in points/second (10...300, default 60).
    var speed: Double = 60
}
