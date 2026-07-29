
## WP3 — Editor (2026-07-30)
- **modifiedDate debounce = 400 ms.** PLAN says "every keystroke updates modifiedDate"; SPEC only requires edits to update it. Content/title changes persist immediately via SwiftData autosave; the `modifiedDate` bump is debounced 400 ms so a typing burst counts as one modification and the modifiedDate-sorted script list doesn't re-sort on every keystroke.
- **`.id(script.id)` on the editor body.** RootView reuses the EditorView when selection changes; without an identity reset, `onChange(of: title/content)` would fire on script switch and spuriously bump the newly selected script's modifiedDate. Resetting identity per script also resets focus state cleanly.
- **Start Prompter wired to `appState.prompterScript = script`** — the mechanism already exists in the scaffold (App/AppState.swift + RootView overlay), so no TODO stub was needed.
