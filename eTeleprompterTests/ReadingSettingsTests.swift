import XCTest
@testable import eTeleprompter

/// Unit tests for ReadingSettings, PresetPalette, and SettingsStore (WP4).
final class ReadingSettingsTests: XCTestCase {

    // MARK: Defaults (SPEC F3)

    func testDefaultsMatchSpec() {
        let settings = ReadingSettings.default
        XCTAssertEqual(settings.font, .sfPro)
        XCTAssertEqual(settings.fontSize, 48)
        XCTAssertEqual(settings.lineSpacing, 1.4)
        XCTAssertEqual(settings.marginFraction, 0.10)
        XCTAssertEqual(settings.textColorID, "white")
        XCTAssertEqual(settings.backgroundColorID, "black")
        XCTAssertFalse(settings.mirrorHorizontal)
        XCTAssertFalse(settings.flipVertical)
        XCTAssertEqual(settings.rotation, .deg0)
        XCTAssertEqual(settings.speed, 60)
    }

    func testFontListHasFiveSpecFonts() {
        XCTAssertEqual(PrompterFont.allCases.count, 5)
        XCTAssertEqual(PrompterFont.allCases.map(\.displayName),
                       ["SF Pro", "New York", "Helvetica Neue", "Georgia", "Menlo"])
    }

    func testRotationCoversAllFourAngles() {
        XCTAssertEqual(RotationAngle.allCases.map(\.rawValue), [0, 90, 180, 270])
        XCTAssertEqual(RotationAngle.deg270.degrees, 270)
    }

    // MARK: Palette

    func testPaletteHasEightSwatchesWithUniqueIDs() {
        XCTAssertEqual(PresetPalette.swatches.count, 8)
        XCTAssertEqual(Set(PresetPalette.swatches.map(\.id)).count, 8)
    }

    func testPaletteLookupByID() {
        XCTAssertEqual(PresetPalette.color(withID: "white"), PresetPalette.white)
        XCTAssertNil(PresetPalette.color(withID: "magenta"))
    }

    func testUnknownColorIDFallsBackToDefaults() {
        var settings = ReadingSettings.default
        settings.textColorID = "nope"
        settings.backgroundColorID = "nada"
        XCTAssertEqual(settings.textColor, PresetPalette.white)
        XCTAssertEqual(settings.backgroundColor, PresetPalette.black)
    }

    // MARK: Codable round-trip

    func testEncodeDecodeRoundTrip() throws {
        var settings = ReadingSettings()
        settings.font = .georgia
        settings.fontSize = 96
        settings.lineSpacing = 1.8
        settings.marginFraction = 0.25
        settings.textColorID = PresetPalette.yellow.id
        settings.backgroundColorID = PresetPalette.gray.id
        settings.mirrorHorizontal = true
        settings.flipVertical = true
        settings.rotation = .deg180
        settings.speed = 120

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ReadingSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    // MARK: SettingsStore persistence

    private func makeSuite(_ name: String = #function) -> UserDefaults {
        let suiteName = "eTeleprompterTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testStoreStartsWithDefaultsWhenEmpty() {
        let store = SettingsStore(userDefaults: makeSuite())
        XCTAssertEqual(store.settings, .default)
    }

    func testStorePersistsAcrossInstances() {
        let defaults = makeSuite()

        let store = SettingsStore(userDefaults: defaults)
        store.settings.font = .menlo
        store.settings.fontSize = 72
        store.settings.mirrorHorizontal = true
        store.settings.rotation = .deg90
        store.settings.textColorID = PresetPalette.cyan.id

        let relaunched = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(relaunched.settings.font, .menlo)
        XCTAssertEqual(relaunched.settings.fontSize, 72)
        XCTAssertTrue(relaunched.settings.mirrorHorizontal)
        XCTAssertEqual(relaunched.settings.rotation, .deg90)
        XCTAssertEqual(relaunched.settings.textColorID, "cyan")
        XCTAssertEqual(relaunched.settings, store.settings)
    }

    func testStoreRecoversFromCorruptData() {
        let defaults = makeSuite()
        defaults.set(Data("not json".utf8), forKey: SettingsStore.storageKey)

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.settings, .default,
                       "corrupt persisted data falls back to SPEC defaults")
    }
}
