import SwiftUI

/// Mirror-mode transforms (SPEC F3): horizontal mirror, vertical flip and
/// rotation, applied to the READING CONTAINER ONLY — the control overlay and
/// settings UI are siblings outside this modifier and stay readable.
///
/// `scaleEffect`/`rotationEffect` are pure render effects: they never
/// invalidate layout or touch the engine, so toggling them mid-playback is
/// instant and uninterrupting (SPEC acceptance 8).
struct MirrorTransformModifier: ViewModifier {
    let settings: ReadingSettings

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: settings.mirrorHorizontal ? -1 : 1,
                         y: settings.flipVertical ? -1 : 1)
            .rotationEffect(.degrees(settings.rotation.degrees))
    }
}

extension View {
    /// Applies the mirror/flip/rotation transforms from `settings`.
    func mirrorTransforms(_ settings: ReadingSettings) -> some View {
        modifier(MirrorTransformModifier(settings: settings))
    }
}
