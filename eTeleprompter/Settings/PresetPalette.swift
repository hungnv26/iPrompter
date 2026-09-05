import Foundation

/// One swatch of the fixed color palette. Colors are stored in settings by
/// `id` (stable string identifier), never as raw color values, so the palette
/// can be tweaked without breaking persisted settings. Components are sRGB
/// 0...1 — the view layer maps them to `Color(red:green:blue:)`.
struct PresetColor: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let red: Double
    let green: Double
    let blue: Double
}

/// The 8-swatch preset palette used for both text and background colors
/// (SPEC F3: no custom color picker). Defaults are white text on black.
enum PresetPalette {
    static let black = PresetColor(id: "black", name: "Black", red: 0, green: 0, blue: 0)
    static let gray = PresetColor(id: "gray", name: "Gray", red: 0.56, green: 0.56, blue: 0.58)
    static let white = PresetColor(id: "white", name: "White", red: 1, green: 1, blue: 1)
    static let yellow = PresetColor(id: "yellow", name: "Yellow", red: 1, green: 0.84, blue: 0.04)
    static let orange = PresetColor(id: "orange", name: "Orange", red: 1, green: 0.58, blue: 0)
    static let red = PresetColor(id: "red", name: "Red", red: 1, green: 0.27, blue: 0.23)
    static let green = PresetColor(id: "green", name: "Green", red: 0.2, green: 0.84, blue: 0.29)
    static let cyan = PresetColor(id: "cyan", name: "Cyan", red: 0.39, green: 0.82, blue: 1)

    /// All 8 swatches, in display order.
    static let swatches: [PresetColor] = [
        black, gray, white, yellow, orange, red, green, cyan,
    ]

    /// Looks up a swatch by its stable identifier.
    static func color(withID id: String) -> PresetColor? {
        swatches.first { $0.id == id }
    }
}
