import Foundation
import Observation

/// App-wide UI state shared through the SwiftUI environment.
/// Owned by scaffold. Interface changes require tech-lead sign-off (see team/PLAN.md).
@Observable
final class AppState {
    /// Non-nil while the full-screen prompter is presented (RootView overlays PrompterView).
    /// Set by the Editor's "Start Prompter" button; cleared by PrompterView on exit.
    var prompterScript: Script?
}
