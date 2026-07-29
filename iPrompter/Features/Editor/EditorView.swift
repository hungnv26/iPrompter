import SwiftUI
import SwiftData

/// Editor (WP3): title field + full-height plain-text editor. Every edit is
/// persisted by SwiftData autosave — there is no Save button (SPEC F1).
/// `modifiedDate` is bumped with a short debounce so continuous typing does
/// not thrash the store or re-sort the script list on every keystroke.
/// Toolbar shows live word count + reading time and a prominent
/// Start Prompter button (SPEC §5.3).
struct EditorView: View {
    @Bindable var script: Script
    @Environment(AppState.self) private var appState

    @FocusState private var focusedField: Field?
    @State private var modifiedDateDebounce: Task<Void, Never>?

    private enum Field: Hashable {
        case title, content
    }

    /// Debounce for `modifiedDate` bumps while typing (content itself is
    /// autosaved by SwiftData independently of this).
    private static let modifiedDateDebounceInterval: Duration = .milliseconds(400)

    /// Comfortable reading/writing size on both an iPad at arm's length and a
    /// Mac display; paired with generous line spacing below.
    private var contentFont: Font { .system(size: 18) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleField
            contentEditor
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(script.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .onChange(of: script.title) { _, _ in scheduleModifiedDateBump() }
        .onChange(of: script.content) { _, _ in scheduleModifiedDateBump() }
        // Reset editor state (focus, pending onChange comparisons) when a
        // different script is shown, so switching scripts never bumps the
        // newly selected script's modifiedDate.
        .id(script.id)
    }

    // MARK: - Subviews

    private var titleField: some View {
        TextField("Untitled", text: $script.title)
            .textFieldStyle(.plain)
            .font(.largeTitle.bold())
            .focused($focusedField, equals: .title)
            .onSubmit { focusedField = .content }
            .padding(.horizontal, 5)
            .accessibilityLabel("Script title")
    }

    private var contentEditor: some View {
        ZStack(alignment: .topLeading) {
            if script.content.isEmpty {
                Text("Start typing your script…")
                    .font(contentFont)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $script.content)
                .font(contentFont)
                .lineSpacing(7)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .content)
                .accessibilityLabel("Script content")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            statsLabel
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                appState.prompterScript = script
            } label: {
                Label("Start Prompter", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .help("Start Prompter")
        }
    }

    /// Live word count + estimated reading time (recomputed as the user
    /// types via the Script model's computed properties).
    private var statsLabel: some View {
        Text("\(script.wordCount) words · \(ReadingTimeFormatter.string(from: script.estimatedReadingTime))")
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityLabel(
                "\(script.wordCount) words, estimated reading time \(ReadingTimeFormatter.string(from: script.estimatedReadingTime))"
            )
    }

    // MARK: - Auto-save

    /// Content/title edits persist immediately via SwiftData autosave; this
    /// only debounces the `modifiedDate` bump so a typing burst counts as one
    /// modification instead of thrashing on every keystroke.
    private func scheduleModifiedDateBump() {
        modifiedDateDebounce?.cancel()
        let script = script
        modifiedDateDebounce = Task { @MainActor in
            try? await Task.sleep(for: Self.modifiedDateDebounceInterval)
            guard !Task.isCancelled else { return }
            script.modifiedDate = .now
        }
    }
}
