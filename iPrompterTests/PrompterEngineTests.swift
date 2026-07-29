import XCTest
@testable import iPrompter

/// Unit tests for the UI-independent PrompterEngine (WP4).
final class PrompterEngineTests: XCTestCase {
    func testEngineStartsAtZeroOffset() {
        XCTAssertEqual(PrompterEngine().offset, 0)
    }
}
