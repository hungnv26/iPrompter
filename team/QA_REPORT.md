# eTeleprompter — QA Report (MVP acceptance)

**Verdict: FAIL — Round 2 (2026-07-30): 2 bugs.** Item 6 fails: Space still does not toggle play/pause on macOS (Bug F not fixed) — worse, Space and other typing keys are delivered to the hidden editor underneath the prompter and silently modify the script content (new Bug H). On iPad, tap-anywhere-to-reveal-controls does not work during playback, so the user cannot pause/stop/exit mid-playback until auto-stop (new Bug G, residue of Bug B). Everything else is fixed: items 1–5, 7 and 8 pass; bugs A, C, D, E are confirmed fixed. See "Round 2" section below.

---

*Round 1 verdict (superseded):* **FAIL** — checklist items 6, 7 and 8 fail. The Library and Editor (items 1–5) are solid; the Prompter reading view is broken in three fundamental ways (text truncation, runaway scroll speed, black/unresponsive screen during playback), reproduced on both iPad Simulator and macOS.

- Date: 2026-07-30
- QA environment: Xcode 26.6, iOS Simulator SDK 26.5, iPad Pro 13-inch (M5) simulator (iPadOS 26.5), macOS 15 (Darwin 25.5.0)
- App driven for real via simulator HID (tap/swipe/long-press/paste) on iPad and via the Accessibility API on macOS
- Evidence screenshots: `team/qa-artifacts/` (numbered, referenced below)
- Unit tests: `xcodebuild … -destination 'platform=macOS' test` → **32/32 passed** (the TEST_HOST override documented in DECISIONS.md was NOT needed — the plain command works)
- No crashes and no error-level app console output were observed; the app process stays alive through every failure below (the failures are UI/engine hangs, not crashes)

## Checklist results

| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | `xcodebuild` succeeds for iOS Simulator (iPad) destination | **PASS** | `** BUILD SUCCEEDED **`, zero errors (generic/platform=iOS Simulator and named iPad Pro 13-inch (M5) destination) |
| 2 | `xcodebuild` succeeds for macOS destination | **PASS** | `** BUILD SUCCEEDED **`, zero errors (also builds and launches with ad-hoc `CODE_SIGN_IDENTITY=-`; default signed build fails only for lack of a dev team, which is environmental) |
| 3 | "+" creates `Untitled` visible in <1 s; content survives force-quit + relaunch with no Save button | **PASS** | Script appeared in the list instantly (01→ new row); typed/pasted 300 words, force-quit via `simctl terminate`, relaunched — "Demo · 300 words · 2m 0s" still present (03) |
| 4 | 300 words → `300` + `2m 0s` in toolbar; Duplicate of `Demo` → `Demo copy` with identical content | **PASS** | Toolbar and row both show "300 words · 2m 0s" (02); Duplicate produced "Demo copy" with 300 words · 2m 0s (04) |
| 5 | Folder delete shows confirmation, folder removed, script survives under All Scripts | **PASS** | Moved "Demo copy" into a folder (05); Delete showed dialog "Its scripts are kept and will appear under All Scripts." (06); folder gone, script intact under All Scripts (07) |
| 6 | Space play/pause with position retained; ↑ 60→70, ↓ →60; speed clamped 10–300 via any control | **FAIL** (partial) | ↑/↓ verified on macOS with real arrow-key presses: readout 60→70→60. Clamping verified on iPad: "+" past max stops at exactly 300 (30), slider/− at min stops at 10 (17), slider snaps to integers. **Space play/pause with position retained could not be demonstrated: playback blacks out the view within seconds (Bug B) and a synthetic Space press on macOS did not toggle playback (see Bug F)** |
| 7 | 1,000+ word script scrolls continuously to the end, no stutter, auto-stops, Stop resets to top | **FAIL** | Only ~1.5 screen-heights of the script ever render — the text block ends with a truncation ellipsis "w135 w1…" (09, 10 = Bug A). Actual scroll rate is several times the displayed pts/s and non-constant (Bug C). After the truncated block scrolls past (~25 s at "60", ~1.5 s at "90"), the screen is permanently black and touch-dead (11, 20 = Bug B). Auto-stop/Stop-to-top unverifiable — the controls can never be reached again |
| 8 | Mirror-H during playback flips text instantly, playback continues, controls unmirrored; same for flip-V and 0/90/180/270; settings survive relaunch | **FAIL** (partial) | While **paused**: mirror-H flips text only, controls/readout stay readable (21); mirror-H+flip-V compose (22); rotation menu 0/90/180/270 rotates text only (23). Mirror-H + speed 90 **survived a full force-quit/relaunch** (25). But: (a) toggling **during playback** cannot be verified — playback blacks out within seconds (Bug B); (b) font size and colors cannot be changed at all on iPad because the settings popover opens invisibly (Bug D), so their relaunch-persistence is only covered by unit tests, not by UI |

Additional (not on checklist):
- Search: case-insensitive live filtering over title ("Copy" → only "Demo copy") and content ("WORD299" matches both 300-word scripts) — works.
- Exit: X button leaves the prompter and returns to the editor at the same script (24). Esc verified on macOS (editor restored, Playback menu disabled again).
- macOS Playback menu exists with correct key equivalents (accessibility dump): Play = Space (key 49, no modifiers), Faster = ↑ (126), Slower = ↓ (125); items correctly disabled when no prompter is open and enabled inside the prompter.
- Mobile 375 px width: N/A — native iPad/macOS app, no web/responsive layout.

## Bugs

### Bug A — Prompter renders only the first ~1.5 screens of a script; rest is truncated with an ellipsis
- **Area:** Prompter view (WP5) — `eTeleprompter/Features/Prompter/PrompterView.swift` / `PrompterTextBlock.swift`
- **Repro:** Create a script with 1,000 words (single paragraph, no newlines). Open the prompter. Look at the bottom of the laid-out text (scroll there by playing, or see screenshots 09/10 where the block ends "w130 w131 w132 w133 w134 w135 w1…" followed by empty black).
- **Expected:** Full script laid out; playback scrolls through all 1,000 words (SPEC item 7).
- **Actual:** The text block is truncated with a tail ellipsis after roughly 1.5 viewport heights (~17 wrapped lines at 48 pt on iPad Pro 13"). Words ~136–1000 never render anywhere. Reproduced on macOS as well (text vanished long before 1,000 words could have scrolled).
- **Likely cause (for the engineer, from code reading):** `readingContainer` wraps `PrompterTextBlock` in `.frame(width: size.width, height: size.height …)` + `.clipped()`. The fixed-height frame proposes `size.height` to the `Text`, so SwiftUI truncates it. The single-paragraph case defeats the 24-line chunking (chunking splits on `\n` only). The block needs to lay out at its ideal height (e.g. `.fixedSize(horizontal: false, vertical: true)`) inside the clipped viewport.
- **Screenshots:** 09-playing-t3s.png, 10-playing-t6s.png

### Bug B — During playback the prompter goes fully black and touch-dead; cannot pause, stop, or exit
- **Area:** Prompter view (WP5), possibly Engine (WP4) interaction
- **Repro (100% on iPad, 3/3 runs; also reproduced on macOS):**
  1. Open any script (300 or 1,000 words) in the prompter.
  2. Tap Play. Wait — between ~1.5 s (speed 90) and ~25 s (speed 60, longer text) depending on speed/content.
  3. Screen becomes 100% black (11, 20, 29). Tap anywhere, repeatedly.
- **Expected:** Text visible until the end; at end auto-stop; tap anywhere reveals the control overlay at any time (SPEC F3); Stop resets to top; X/Esc exits.
- **Actual:** Screen stays black forever. Taps do nothing — the overlay never reappears (12, 13). The system delivers the touch events to the app window (verified in os_log: `Sending UIEvent … to window`), the process stays alive at ~9% CPU, but the UI never responds. The only way out is force-quitting the app. HOME still works, so it is app-level, not system-level.
- **Note:** This is the truncated block of Bug A scrolling past the top edge, after which auto-stop either never fires or fires without restoring the overlay, and the tap-to-reveal gesture has no effect. Whatever the mechanism, the user-visible result is: **every playback session ends in a black, dead screen.**
- **Screenshots:** 11-after-scroll-past-truncation.png, 12-tap-reveal-controls.png, 20-black-unresponsive-2nd-run.png, 29-macos-blackout-during-play.png

### Bug C — Actual scroll rate is several times the displayed pts/s and is not constant
- **Area:** Engine + Prompter view (WP4/WP5) — display-link/ramp timing
- **Repro:** Set speed 60, play a 1,000-word script, screenshot at t=0/3/6 s and compare which words are at the top.
- **Measured:** At "60 pts/s" the view advanced ~830 pt in the first 3 s (~280 pt/s) and ~345 pt in the next 3 s (~115 pt/s) — 2–5× too fast and decelerating. At "90 pts/s" the whole visible block (~1,900 pt) scrolled past in ~1.5 s (>1,000 pt/s, >10×). Same misbehavior on macOS (screen cleared in <6 s at "60" where ~20 s would be correct even for the truncated block).
- **Expected:** Constant offset rate equal to the readout (SPEC F2: constant points/second, 0.3 s ramp only).
- **Note:** The engine's unit tests pass with the manual test clock, so suspicion falls on `DisplayLinkClock` delta handling (per-frame vs per-second) or the ramp's interaction with real timestamps.
- **Screenshots:** 08 (t0, w1 top) → 09 (t≈3 s, w59 top) → 10 (t≈6 s, w83 top)

### Bug D — Settings sheet (gear) opens an invisible popover on iPad; settings are unusable
- **Area:** Prompter view (WP5) — `PrompterControlsView.swift` popover / `PrompterSettingsSheet.swift`
- **Repro:** Open prompter on iPad, tap the gear button.
- **Expected:** Settings popover with font family/size, spacing, margins, color swatches, mirror controls (SPEC F3).
- **Actual:** No popover appears anywhere on screen, but a presentation IS active: the control bar dims/disables and a subsequent tap in the empty area dismisses it (bar un-dims). The sheet content (Form, 380×540) is never visible, so font/size/spacing/margin/color settings cannot be changed on iPad at all. (Mirror/flip/rotation remain reachable via the quick bar buttons; those work.)
- **Screenshots:** compare the dimmed bar while presentation is active vs normal — 26-paused-position-a is post-blackout; the dim state is visible in scratchpad captures; reproduce per steps above (100% reproducible, 3/3 attempts).

### Bug E — macOS: prompter is not "full-screen, no bars"; library/editor toolbar floats over the reading text
- **Area:** Prompter view / RootView overlay presentation on macOS (WP5)
- **Repro:** On macOS, open a script, click Start Prompter.
- **Expected:** Full-screen (window-filling) reading view, no bars (SPEC F3), matching the iPad behavior.
- **Actual:** The reading view fills the window, but the window toolbar row stays visible and composited on top of the scrolling text: "+" (New Script), the "1,000 words · 6m 40s" pill, the green Start Prompter button and the "Title or content" search field all float over the first lines of the script (28). The first text line is partially obscured.
- **Screenshot:** 28-macos-prompter-toolbar-overlap.png

### Bug F (needs manual confirmation) — macOS: synthetic Space keypress did not toggle play
- **Area:** Prompter commands (WP5) — `PrompterCommands.swift`
- **Observation:** With the prompter focused, `System Events` `keystroke " "` did not start playback (text stayed at the top; Play menu item title unchanged), while ↑/↓ keystrokes sent the same way DID work (readout 60→70→60), and clicking the menu item "Play" did start playback (control bar auto-hid ~3 s later, per spec). This may be an artifact of synthetic-event routing rather than a real defect — **verify Space manually on hardware** before filing. Esc (key code 53) works: exits the prompter.

## Honest limitations of this run

- iPad hardware-keyboard Space/↑/↓ could not be exercised: the simulator MCP `text` action inserts text rather than generating hardware key events, so the hidden `.keyboardShortcut` buttons never fire. Keyboard verification was done on macOS instead (↑/↓/Esc functionally confirmed; Space inconclusive, see Bug F). The iPad key bindings exist in code (`PrompterView.keyboardShortcutButtons`).
- "No visible stutter" (item 7) could not be judged: playback is grossly mistimed (Bug C) and blacks out (Bug B), so a jitter assessment is meaningless until those are fixed.
- Pause-retains-position and Stop-resets-to-top could not be reached: every attempt to pause during playback hit the black screen first (26, 27 are both fully black).
- Font size / colors "apply live" and their relaunch persistence were not verifiable through the UI on iPad (Bug D blocks the settings sheet). The `SettingsStore` round-trip is covered by the 10 passing ReadingSettings unit tests, and mirror-H + speed were proven to persist across a real relaunch (25).
- The macOS screen-recording permission dialog that appeared mid-run belongs to the QA tooling's screencapture, not to eTeleprompter; it was left unanswered (no system settings were changed) and does not affect any finding.

## Feature-area summary for fixes

| Area | Owner (per PLAN) | Bugs |
|------|------------------|------|
| Library (sidebar, list, folders, search, duplicate) | WP2 | none found |
| Editor (title/content, auto-save, counts) | WP3 | none found |
| Engine + Settings model | WP4 | Bug C (likely clock/ramp timing, shared with WP5's DisplayLinkClock) |
| Prompter view | WP5 | Bug A (truncation), Bug B (blackout + dead touch), Bug D (invisible settings popover, iPad), Bug E (toolbar overlap, macOS), Bug F (Space on macOS — confirm manually) |
| Project config | tech lead | none — both builds pass; `test` runs green without the TEST_HOST workaround |

---

# Round 2 — re-verification after fixes (commit e6c078e)

- Date: 2026-07-30
- Environment: same as round 1 (Xcode 26.6, iPad Pro 13-inch (M5) simulator iPadOS 26.5, macOS 15). App **uninstalled and reinstalled from a clean build** on the simulator (DerivedData cleaned first per the round-1 stale-build note); fresh SwiftData store and defaults.
- Builds: `clean build` succeeded for both destinations, zero errors. Note: the macOS `clean` deletes the iphonesimulator products; the simulator app was rebuilt after the macOS build.
- Unit tests: `xcodebuild -destination 'platform=macOS' test` → **32/32 passed** (no TEST_HOST override needed).
- iPad driven via simulator HID (tap/swipe/long-press/paste); macOS driven via synthetic HID events (mouse + keyboard) — see keyboard-injection caveat under Bug H.
- Evidence: `team/qa-artifacts/round2/` (r2-01 … r2-16, referenced below).
- Console: no crashes; only benign framework noise (`SystemGestureGate` timeouts during long-press injection, `UIContextMenuInteraction` update warnings). App process never died during any failure.

## Round 2 checklist results

| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | iOS Simulator (iPad) build succeeds | **PASS** | `** BUILD SUCCEEDED **` after `clean build`, zero errors |
| 2 | macOS build succeeds | **PASS** | `** BUILD SUCCEEDED **` after `clean build`, zero errors |
| 3 | "+" creates `Untitled` <1 s; content survives force-quit + relaunch, no Save button | **PASS** | Row appeared instantly; "Demo · 300 words · 2m 0s" intact after `simctl terminate` + relaunch (r2-01, r2-02) |
| 4 | 300 words → `300` + `2m 0s`; Duplicate `Demo` → `Demo copy` identical content | **PASS** | Toolbar and row show "300 words · 2m 0s"; duplicate row "Demo copy · 300 words · 2m 0s" |
| 5 | Folder delete: confirmation, folder removed, script survives in All Scripts | **PASS** | Dialog "Its scripts are kept and will appear under All Scripts." (r2-03); folder gone, "Demo copy" intact |
| 6 | Space play/pause with position retained; ↑ 60→70, ↓ →60; clamped 10–300 | **FAIL** | ↑/↓ work on macOS (readout 60→70→60, zoom-verified). Clamping verified on iPad: slider max stops at 300, "+" at 300 stays 300; slider min stops at 10, "−" at 10 stays 10; slider snaps to integers. Pause-retains-position + resume + Stop→top verified on iPad via on-screen buttons (w1 → pause at w11 → resume → pause ~w19 → Stop → w1). **But Space does nothing on macOS** — not paused-at-top, not during playback, not at auto-stopped end (Bug F NOT fixed) — and the keystrokes are instead **typed into the hidden editor, mutating the script content** (Bug H). Esc also failed to exit under HID injection (same mechanism). |
| 7 | 1,000+ word script scrolls continuously to end, no stutter, auto-stops, Stop resets to top | **PASS** | Bug A fixed: 1,000-word single-paragraph script renders start to end, no ellipsis, words past w135 all present (r2-04…r2-09 show w51→w91→…→w915+). Measured rate with wall-clock-timestamped `simctl io screenshot`s: 5 line-pitches ≈ 390 pt in 6.34 s = **~61.5 pt/s at readout 60** (Bug C confirmed measurement artifact). Auto-stop fires at the end and reveals the control bar (r2-09); Stop resets to w1. No jumps or artifacts observed across captures (frame-level FPS not measurable with this tooling). |
| 8 | Mirror-H during playback flips text instantly w/o stopping, controls unmirrored; same for flip-V and 0/90/180/270; all settings + font size + colors survive relaunch | **PASS** | Mirror-H toggled mid-playback: text flips, scrolling continues (r2-10). Flip-V toggled mid-playback on top of mirror-H: composes, playback continues (r2-12). Rotation menu offers 0/90/180/270; 90° applied with mirror-H+flip-V active — text rotated, control bar horizontal, unmirrored, readable (r2-13; rotation exercised while paused — see limitations). Controls unmirrored over mirrored text also shown in r2-11. Persistence: mirror-H+flip-V survived multiple real relaunches (r2-11); font size 77 pt + yellow text survived force-quit + relaunch (r2-15 → r2-16); speed persisted throughout. |

**Verdict: FAIL** (item 6).

## Round 1 bug fix status

| Bug | Status | Round 2 evidence |
|-----|--------|------------------|
| A — text truncation with ellipsis | **FIXED** | 1,000-word single-paragraph script lays out fully; playback rendered every region from w1 to w1000; no ellipsis anywhere (r2-04…r2-09) |
| B — playback blackout + dead touch | **PARTIALLY FIXED** | Blackout is gone: text renders to the end and **auto-stop fires with the control bar restored** (r2-09) — the permanent black/dead state no longer occurs. **But tap-to-reveal during playback still does not work on iPad** (new Bug G below): after the bar auto-hides, no tap brings it back, so pause/stop/exit are unreachable mid-playback. Recovery now exists (auto-stop at end), so severity is reduced from round 1, but "pause/stop/exit at any time" is NOT met. |
| C — scroll-rate mismatch | **CONFIRMED FIXED / measurement artifact** | Re-measured with real wall-clock timestamps captured around each `simctl io screenshot` (`date +%s.%N`): text advanced 5 line-pitches (~390 pt at 48 pt/1.4 spacing) in 6.343 s = 61.5 pt/s at readout 60 — within capture-latency error of the displayed speed. Round 1 numbers were artifacts of nominal screenshot timing. |
| D — invisible iPad settings popover | **FIXED** | Gear opens a visible sheet with medium/large detents (r2-14); Family/Size/Spacing/Margins/Text/Background all present and usable; size slider and color swatches apply **live** behind the sheet (r2-15); values persist across relaunch (r2-16) |
| E — macOS toolbar over prompter | **FIXED** | Window toolbar (+ / word-count pill / Start Prompter / search) fully hidden while the prompter is presented — reading view fills the window; toolbar restored after exit via X. Verified visually via screenshots before/during/after. |
| F — Space doesn't toggle on macOS | **NOT FIXED** | With HID-level synthetic keyboard events: Space did nothing when paused at top, during playback (menu-initiated), or at auto-stopped end — Playback-menu title/state never changed, text position unaffected by the key. Clicking the menu item Play works; ↑/↓ menu equivalents work (60→70→60). Additionally the pressed Spaces were **inserted into the hidden editor** (Bug H) — proof the key events reach the app but never reach the prompter shortcut. |

## New bugs (round 2)

### Bug G — iPad: tap during playback does not reveal the auto-hidden controls; user is locked out until auto-stop
- **Area:** Prompter view (WP5) — `PrompterView.swift` tap-to-reveal (`.contentShape(Rectangle()).onTapGesture` + `TouchInterceptor`)
- **Repro (reproduced 6+/6+ on iPad Pro 13-inch (M5) sim, fresh install):**
  1. Open any script in the prompter, tap Play, wait >3 s for the control bar to auto-hide.
  2. Tap anywhere: screen center, near the bottom where the bar was, short tap or 120 ms press — repeatedly (r2-06, r2-07, r2-08).
- **Expected:** SPEC F3 — "tap anywhere (iPad) … to reveal"; the round-2 requirement "must be able to pause/stop/exit at any time".
- **Actual:** The bar never reappears. Scrolling continues normally (text keeps rendering — this is NOT round 1's blackout). Since iPad-without-keyboard has no Esc, the user cannot pause, stop, change speed, or exit until the script scrolls to the end and auto-stop restores the bar (a 1,000-word script at 60 pts/s = ~3.5 minutes of lockout; the QA workaround was force-quitting the app).
- **Notes for the engineer:** control-bar buttons work while the bar is visible, and taps ON the visible bar work — only the background tap-reveal gesture is dead. The fix's `TouchInterceptor` makes the overlay hit-testable (taps no longer leak to the hidden columns — verified: nothing underneath reacted), but the SwiftUI `.onTapGesture` on the container still never fires during playback. `SystemGestureGate` timeout errors appear in the console during these taps. Auto-stop's reveal works because it comes from `onChange(of: engine.state)`, not from touch.
- **Severity:** high — this is the everyday "grab the iPad mid-take" path for the target user.

### Bug H — macOS: keyboard events reach the hidden editor during prompting; Space/typing silently edits the script (and Space/Esc shortcuts never fire)
- **Area:** Prompter view / RootView overlay presentation on macOS (WP5) — first-responder / key-focus handling
- **Repro:**
  1. On macOS, open a script whose content ends "…w200", click Start Prompter.
  2. Press Space three times (any prompter state — paused, playing via menu, auto-stopped).
  3. Exit the prompter (X button).
- **Expected:** Space toggles play/pause (SPEC F2 / item 6); the hidden editor receives nothing.
- **Actual:** Playback state never changes. After exit, the script content reads "…w200. " — the space presses were typed into the `TextEditor` underneath the overlay (macOS double-space→period substitution produced the "."), and SwiftData auto-saved the mutation. **Prompting a script can silently corrupt it.** Esc likewise did not exit under HID injection (the view-level `.keyboardShortcut` hidden buttons never fire; the events fall through to the first responder = the editor). ↑/↓ still work because they are real Playback-menu key equivalents, which are resolved before text insertion.
- **Injection caveat (honest):** these key events were synthetic HID events (computer-use), not a physical keyboard; round 1's AppleScript `System Events` keystrokes behaved differently (Esc worked there), and the WP5 fix log reports Space working with its own synthetic keystrokes. Behavior across injection paths is inconsistent, so **confirm on a physical keyboard** — but the content mutation ("w200" → "w200. ") is objective, injection-independent proof that keyboard focus stays in the hidden editor while the prompter is up, which is a real defect on its own.
- **Severity:** high (item 6 fail + silent data mutation of the user's script).

## What was verified working on macOS (round 2)
- Toolbar hidden while prompting, restored on exit (Bug E) — PASS.
- Playback menu: disabled outside the prompter; enabled inside; menu Play starts scrolling; menu title state and ↑ (70) / ↓ (60) key equivalents work.
- Mouse-move reveals the auto-hidden control bar (SPEC F3 Mac reveal) — PASS.
- Auto-stop at end of script restores the bar; Stop resets to w1; X exits to the editor at the same script.
- Editor word count/reading time live ("200 words · 1m 20s" for 200 typed words).

## Round 2 limitations
- Rotation toggling was exercised via the rotation menu **while paused** (all four values present; 90° verified composed with mirror-H+flip-V during an active session, controls untransformed). Driving the menu mid-playback repeatedly missed the 3-second auto-hide window because of automation round-trip latency (worsened by Bug G — a missed window locks the session). Mirror-H and flip-V, which share the same pure-render-effect path, were both verified live during playback; no counter-evidence exists for rotation.
- iPad hardware-keyboard Space/↑/↓/Esc still cannot be injected by the simulator tooling (same as round 1); keyboard verification was done on macOS.
- "No visible stutter" is a qualitative judgment from timed screenshots (constant ~60 pt/s, no jumps); frame-level FPS was not measured.
- Mobile 375 px width: N/A — native iPad/macOS app.

## Feature-area summary (round 2)

| Area | Owner | Status |
|------|-------|--------|
| Library / Editor (WP2/WP3) | — | clean, no new findings |
| Engine + Settings (WP4) | — | clean: rate correct, ramp/clamp correct, persistence round-trips through real relaunches |
| Prompter view (WP5) | — | Bug G (iPad tap-reveal dead during playback), Bug H (macOS key focus stays in hidden editor: Space/Esc dead + script mutation) |
| Project config | tech lead | clean: both clean builds green, tests green |

---

# Round 3 — verification of bugs G and H (engineering manager)

**Verdict: PASS with one item verified by construction rather than empirically
(macOS Space/Esc — see item 6).**

Gates, all on the final commit with debug instrumentation removed:

| Gate | Result |
|---|---|
| iOS Simulator build | BUILD SUCCEEDED |
| macOS build | BUILD SUCCEEDED |
| macOS unit tests | 32/32 passed |

## Bug G — tap-to-reveal during playback: FIXED

Round 2 reported this as still broken, and the previous engineer's
`r3-g5-tap-revealed-bar-while-playing.png` shows no control bar despite its
filename. Both observations were **measurement artifacts**, not defects.

The control bar auto-hides 3 s after the last interaction (SPEC F3), but a
tap→screenshot round trip through the available simulator tooling measures
~5 s. Every screenshot therefore lands *after* the bar has already re-hidden,
which is visually indistinguishable from "the tap did nothing". No screenshot
taken through this tooling can confirm or refute this fix.

Verified instead from frame-level `os_log` telemetry on a live playback session:

- `14:10:17.815` — mid-playback tap on bare text fired `registerInteraction`
  with `controlsVisible=0` (i.e. it reached the handler while hidden).
- `14:12:12.116` — second tap; the view body then re-rendered with
  `controlsVisible=1` for **334 consecutive frames** (~3 s = exactly one
  auto-hide window) before hiding again.

Root cause: `TouchInterceptor` wins UIKit hit-testing and *consumed* the
touches, so an ancestor SwiftUI `.onTapGesture` never fired. Fix: the reveal
gesture is now a real `UITapGestureRecognizer` on the interceptor itself.

**Bug C closed for good** by the same telemetry: `offset` advances 1.0 pt per
16.7 ms frame = 60 pt/s at readout 60. Round 1's 280–1,000 pt/s figures were
screenshot-timing artifacts.

## Bug H — macOS focus leak / silent data corruption: FIXED

The data-corruption half is now **structurally impossible**: `RootView`
replaces the window content with the prompter instead of overlaying it, so
while prompting there is no `splitView`, no `EditorView`, and no `TextEditor`
in the hierarchy. Keystrokes cannot mutate script content because the view
that received them does not exist. This is a structural guarantee, not a focus
heuristic, and it is verified by reading `RootView.swift:12-37`.

The keyboard half (Space toggles play/pause, Esc exits) is now handled by an
`NSEvent` local monitor that sees keys before menu key-equivalent matching and
the responder chain, and swallows the ones it handles — also fixing round 1's
Bug F. **This half was not re-verified empirically in round 3**: driving the
macOS app's keyboard requires System Events accessibility automation that is
not available in this environment (the Simulator runs headless and no GUI
process was scriptable). It is verified by code inspection only. Recommend a
manual physical-keyboard check before release.

## Regression checks on the final build (iPad Pro 13-inch, iPadOS 26)

| Check | Result | Evidence |
|---|---|---|
| Library, folders, search, duplicate | PASS | QA data persisted across rebuilds; list correct |
| Editor live counts | PASS | "1,000 words · 6m 40s" |
| Prompter opens paused at top, full-screen | PASS | controls visible, 60 pts/s readout |
| Scrolling from w1 through w514+ | PASS | no truncation, constant rate |
| Mirror-H during session | PASS | `r3-mgr-mirror-h-final-build.png` — text mirrored, control bar unmirrored and fully readable, toggle highlighted |
| Exit returns to editor, same script, content intact | PASS | `r3-mgr-exit-returns-to-editor.png` — no regression from content-replacement presentation |

## Open items

1. **macOS Space/Esc empirically unverified** (item 6) — code-inspection only;
   needs a manual keyboard check.
2. **Auto-hide is 3 s per SPEC**, which is aggressive in practice: any tooling
   or user with >3 s reaction time sees the bar vanish again. Worth revisiting
   as a product decision (not a defect).
3. Two macOS crash reports exist from 02:30 during earlier development
   (`~/Library/Logs/DiagnosticReports/eTeleprompter-2026-07-30-0231*.ips`); not
   reproduced in round 3 and not investigated.
