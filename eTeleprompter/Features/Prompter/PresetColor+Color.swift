import SwiftUI

/// Settings/ is SwiftUI-free (WP4), so the mapping from a palette swatch to a
/// SwiftUI `Color` lives here in the view layer (WP5).
extension PresetColor {
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
