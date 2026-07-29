# Decisions log

Append-only. Record decisions made where SPEC/PLAN was ambiguous.

## WP2 — Library (2026-07-30)

1. **New script inherits the selected folder.** SPEC F1 does not say where a
   "+"-created script lives. When a folder is selected in the sidebar, the new
   script is created in that folder (otherwise it would be invisible in the
   current list); under All Scripts it is created with no folder.
2. **Duplicate naming is fully Finder-style.** SPEC gives `<Title> copy` →
   `<Title> copy 2` and cites Finder as the rationale, so duplicating a script
   already named `Demo copy` yields `Demo copy 2` (the trailing " copy"/
   " copy N" suffix is treated as copy numbering, not part of the base name).
   Uniqueness is checked against all script titles. (`DuplicateNamer.swift`.)
3. **Folders sort by name.** SPEC specifies sorting only for scripts; the
   sidebar folder list is sorted by name ascending.
4. **Reading-time formatting is file-private in Library.** WP3 owns the shared
   `ReadingTimeFormatter` in Features/Editor; to avoid a same-module type-name
   collision across parallel packages, the script row uses a file-private
   helper with the identical "4m 30s"/"45s" output.
5. **Folder deletion does not touch scripts' `modifiedDate`.** Nullify happens
   via the SwiftData delete rule; the user did not edit the scripts, so their
   list order is preserved.
6. **Swipe-to-delete uses a red tinted button, not `role: .destructive`.**
   A destructive-role swipe button animates the row away before the required
   confirmation dialog is answered; the tinted button keeps the row in place
   until the user confirms.


## WP3 — Editor (2026-07-30)
- **modifiedDate debounce = 400 ms.** PLAN says "every keystroke updates modifiedDate"; SPEC only requires edits to update it. Content/title changes persist immediately via SwiftData autosave; the `modifiedDate` bump is debounced 400 ms so a typing burst counts as one modification and the modifiedDate-sorted script list doesn't re-sort on every keystroke.
- **`.id(script.id)` on the editor body.** RootView reuses the EditorView when selection changes; without an identity reset, `onChange(of: title/content)` would fire on script switch and spuriously bump the newly selected script's modifiedDate. Resetting identity per script also resets focus state cleanly.
- **Start Prompter wired to `appState.prompterScript = script`** — the mechanism already exists in the scaffold (App/AppState.swift + RootView overlay), so no TODO stub was needed.

# Decisions log

## WP4 — Engine + Settings model (2026-07-30)

- **Colors persisted as stable string IDs, not palette indices.** PLAN.md says
  "palette indices"; the WP4 brief says "preset identifiers". Chose string IDs
  ("white", "black", …) — reordering or editing the palette can never silently
  change a user's persisted colors. Unknown IDs resolve to the SPEC defaults.
- **SettingsStore writes UserDefaults directly** under the single key
  "readingSettings" (same key/encoding an `@AppStorage("readingSettings")`
  view property would read). `@AppStorage` is a SwiftUI property wrapper and
  cannot live in an @Observable class; this keeps Settings/ SwiftUI-free and
  fully unit-testable via an injected UserDefaults suite.
- **`play()` from the auto-stopped end restarts from the top.** SPEC defines
  auto-stop (offset stays at end) and Stop (reset to top) but not what Play at
  the end does; replaying from the top is the only useful behavior.
- **Pause ramps the rate down over 0.3 s** (position drifts a few points while
  easing out), per SPEC "every speed change (and play/pause) interpolates the
  actual scroll rate … over 0.3 s". Position is retained from wherever the
  ramp ends; the engine keeps the clock alive just long enough to finish the
  ramp-down, then stops it.
- **Speed changes while paused/stopped do not ramp or move anything** — the new
  target simply becomes the ramp destination of the next `play()`.
- **`contentHeight == 0` means "unknown" and disables auto-stop** so the engine
  never instantly stops before the view has measured the text.
- **Project-config bug (tech-lead action needed, WP4 could not fix):** the
  generated pbxproj hardcodes iOS-style
  `TEST_HOST = $(BUILT_PRODUCTS_DIR)/iPrompter.app/iPrompter`, which fails on
  the macOS destination (executable lives in `Contents/MacOS/`). WP4 owns no
  project files, so tests are run with a CLI override:
  `xcodebuild … test CODE_SIGNING_ALLOWED=NO 'TEST_HOST=$(BUILT_PRODUCTS_DIR)/iPrompter.app/Contents/MacOS/iPrompter'`.
  Proper fix in project.yml: set the tests target's TEST_HOST per-platform or
  use `$(BUNDLE_EXECUTABLE_FOLDER_PATH)`.
