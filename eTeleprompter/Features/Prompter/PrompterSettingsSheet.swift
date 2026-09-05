import SwiftUI

/// Compact settings panel (WP5), shown as a popover from the control bar's
/// gear button. Edits the global ReadingSettings live — every change is
/// persisted immediately by SettingsStore and re-styles the reading view
/// without interrupting playback (SPEC F3).
struct PrompterSettingsSheet: View {
    @Bindable var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // QA Bug D: presented as a sheet on iOS (popovers rendered invisibly
        // on iPadOS), as a fixed-size popover on macOS.
        #if os(iOS)
        NavigationStack {
            settingsForm
                .navigationTitle("Reading Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        // .medium showed barely two rows of a four-section form on iPad, so the
        // panel opened looking truncated. A taller default fits Font end-to-end
        // with Colors just below; drag up for the rest.
        .presentationDetents([.fraction(0.68), .large])
        // The prompter behind this sheet is full-screen scrolling text. The
        // default sheet backdrop is translucent enough that the text showed
        // straight through the labels and made them hard to read, so the
        // backdrop is opaque.
        .presentationBackground(Color(.systemGroupedBackground))
        #else
        settingsForm
            .frame(width: 380, height: 540)
        #endif
    }

    private var settingsForm: some View {
        Form {
            Section("Font") {
                Picker("Family", selection: $store.settings.font) {
                    ForEach(PrompterFont.allCases, id: \.self) { font in
                        Text(font.displayName).tag(font)
                    }
                }

                sliderRow("Size",
                          value: $store.settings.fontSize,
                          in: ReadingSettings.fontSizeRange,
                          step: 1,
                          readout: "\(Int(store.settings.fontSize)) pt")

                sliderRow("Spacing",
                          value: $store.settings.lineSpacing,
                          in: ReadingSettings.lineSpacingRange,
                          step: 0.05,
                          readout: String(format: "×%.2f", store.settings.lineSpacing))

                sliderRow("Margins",
                          value: $store.settings.marginFraction,
                          in: ReadingSettings.marginFractionRange,
                          step: 0.01,
                          readout: "\(Int((store.settings.marginFraction * 100).rounded())) %")
            }

            Section("Colors") {
                swatchRow("Text", selection: $store.settings.textColorID)
                swatchRow("Background", selection: $store.settings.backgroundColorID)
            }

            Section("Mirror") {
                Toggle("Horizontal mirror", isOn: $store.settings.mirrorHorizontal)
                Toggle("Vertical flip", isOn: $store.settings.flipVertical)
                Picker("Rotation", selection: $store.settings.rotation) {
                    ForEach(RotationAngle.allCases, id: \.self) { angle in
                        Text("\(angle.rawValue)°").tag(angle)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Slider rows

    /// Label and value on one line, slider beneath.
    ///
    /// `LabeledContent` with a Slider in its content closure does not survive
    /// the narrow width this panel gets: the slider claimed the whole row and
    /// pushed the label and readout onto their own lines, so the panel read as
    /// a stack of unlabelled sliders. Laying it out explicitly keeps every
    /// control captioned at any width, on both platforms.
    private func sliderRow(_ title: String,
                           value: Binding<Double>,
                           in range: ClosedRange<Double>,
                           step: Double,
                           readout: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                Text(readout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(readout)
        }
        .padding(.vertical, 2)
    }

    // MARK: Swatches (8 fixed presets, no custom picker — SPEC F3)

    private func swatchRow(_ title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            HStack(spacing: 10) {
                ForEach(PresetPalette.swatches) { swatch in
                    Button {
                        selection.wrappedValue = swatch.id
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().strokeBorder(.secondary.opacity(0.4),
                                                      lineWidth: 1)
                            )
                            .overlay {
                                if selection.wrappedValue == swatch.id {
                                    Circle()
                                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                        .padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) color \(swatch.name)")
                    .accessibilityAddTraits(
                        selection.wrappedValue == swatch.id ? .isSelected : []
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}
