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
        .presentationDetents([.medium, .large])
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

                LabeledContent("Size") {
                    Slider(value: $store.settings.fontSize,
                           in: ReadingSettings.fontSizeRange,
                           step: 1)
                    Text("\(Int(store.settings.fontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }

                LabeledContent("Spacing") {
                    Slider(value: $store.settings.lineSpacing,
                           in: ReadingSettings.lineSpacingRange,
                           step: 0.05)
                    Text(String(format: "×%.2f", store.settings.lineSpacing))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }

                LabeledContent("Margins") {
                    Slider(value: $store.settings.marginFraction,
                           in: ReadingSettings.marginFractionRange,
                           step: 0.01)
                    Text("\(Int((store.settings.marginFraction * 100).rounded())) %")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
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
