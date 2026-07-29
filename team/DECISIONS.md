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
