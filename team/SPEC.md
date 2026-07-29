# iPrompter — MVP Product Spec

**Product:** iPrompter — a native SwiftUI teleprompter for iPad and Mac.
**Platforms:** One SwiftUI multiplatform target, iPadOS 17+ and macOS 14+ (native, not Catalyst). MVVM, SwiftData persistence. (Locked by customer.)

## 1. Overview and target user

The target user is a presenter — YouTuber, lecturer, executive recording video — who mounts an iPad on a mirror-rig teleprompter or reads directly from a Mac screen. The single primary action of the app: **open a script and scroll it at a steady, controllable speed while reading aloud.** Everything else (organizing, editing, styling, mirroring) exists to make that one action frictionless. The app is fast, minimal, and distraction-free; no accounts, no cloud, no network.

## 2. Core features (exactly 3, covering the 5 locked functions)

### F1. Script library (locked function 1)
- **Create:** "+" creates a script titled `Untitled` with empty content, opens the editor immediately. *Rationale: zero-friction capture; title is editable in place.*
- **Edit:** editor shows a title field and a plain-text content field. All edits auto-save; there is no Save button. Edits update `modifiedDate`. *Rationale: brief mandates auto-save.*
- **Delete:** swipe-to-delete (iPad) and context menu (both platforms), with a confirmation dialog. Delete is permanent (no trash). *Rationale: MVP simplicity; confirmation prevents accidents.*
- **Duplicate:** context-menu action creates a copy with identical content, title `<Title> copy` (then `<Title> copy 2`, `copy 3`, … if taken), fresh `id`/`createdDate`/`modifiedDate`, same folder. *Rationale: Finder-style naming is familiar and collision-free.*
- **Search:** search field above the script list; case-insensitive substring match against title AND content; filters the currently visible list live. *Rationale: content search finds half-remembered scripts.*
- **Folders:** flat, single-level folders (no nesting). Sidebar shows `All Scripts` plus user folders. A script belongs to 0 or 1 folder. Folder names need not be unique. **Deleting a folder never deletes scripts** — its scripts revert to no folder (visible in All Scripts); a confirmation dialog states this. *Rationale: data loss from folder cleanup is unforgivable.*
- **Sorting:** scripts sorted by `modifiedDate` descending, fixed. *Rationale: last-worked-on is what presenters want; no sort UI in MVP.*

### F2. Prompter engine with speed control (locked functions 2 + 5)
- **Engine:** a scrolling engine independent of the view layer drives a scroll offset at constant points/second; views observe it. *Rationale: locked; enables future voice tracking.*
- **Transport:** Play, Pause (position retained), Resume, Stop (resets to top). Reaching the end of the script auto-stops. Opening the prompter starts **paused at the top**. *Rationale: presenters cue up before rolling.*
- **Speed:** measured and displayed numerically in points/second. **Range 10–300 pts/s, default 60, step 10** for buttons/keys; slider is continuous across the range and snaps to integers. *Rationale: 60 pts/s ≈ comfortable speech pace at the default 48 pt font; range covers slow rehearsal to fast skim.*
- **Speed ramp:** every speed change (and play/pause) interpolates the actual scroll rate to the target over **0.3 s** — no sudden jumps, per the brief. Displayed number changes immediately to the target.
- **Controls:** on-screen slider, − and + buttons, numeric speed readout; Play/Pause and Stop buttons. **Keyboard: Space = play/pause, ↑ = +10, ↓ = −10, Esc = exit prompter.** Shortcuts work on macOS and on iPad with a hardware keyboard. *Rationale: Esc is the platform-native exit; the rest is locked.*
- **Performance target:** ≥60 FPS, no visible jitter, on a 10,000-word script at max font size.

### F3. Reading view with mirror mode (locked functions 3 + 4)
- **Reading view:** full-screen, no bars. Controls live in a bottom overlay that **auto-hides after 3 s** of inactivity during playback; tap anywhere (iPad) or move the mouse (Mac) to reveal. *Rationale: distraction-free per the brief, but controls always one gesture away.*
- **Customization (settings sheet, gear icon in overlay):** font size 20–120 pt; font family from a fixed list of 5 system-provided fonts (SF Pro, New York, Helvetica Neue, Georgia, Menlo); line spacing multiplier 1.0–2.0; symmetric left/right margin 0–25% of width; text color and background color, each from an 8-swatch preset palette (no custom color picker). *Rationale: presets keep the UI fast and every combination legible.*
- **Defaults:** SF Pro, 48 pt, line spacing 1.4, margins 10%, white text on black background. *Rationale: white-on-black is the teleprompter industry standard for mirror rigs.*
- **Screen brightness control: not building** (marked optional in brief). *Rationale: OS controls suffice; cut for scope.*
- **Mirror mode:** three independent toggles/settings — horizontal mirror (on/off), vertical flip (on/off), rotation (0°/90°/180°/270°). Transforms apply **only to the scrolling text**, compose in any combination, and take effect instantly without interrupting playback. The control overlay and settings UI are **never mirrored/rotated** and remain readable. *Rationale: the operator reads the controls; only the glass reads the text.*
- **Persistence:** reading + mirror + speed settings are global (not per-script) and persist across launches. *Rationale: one rig, one setup; per-script settings are post-MVP.*

## 3. Not building (MVP)
Voice tracking, camera/recording, cloud sync/iCloud, AI features (locked out) · rich text/Markdown rendering · import/export/share · nested folders, custom sort, tags · per-script settings · remote control (Bluetooth/watch) · countdown timer, progress bar, elapsed-time display · screen-brightness control · iPhone layout · undo history beyond system text-field undo.

## 4. Data model

**Script** (SwiftData model)
- `id: UUID` — stored
- `title: String` — stored
- `content: String` — stored (plain text)
- `createdDate: Date` — stored
- `modifiedDate: Date` — stored, updated on any title/content/folder change
- `folder: Folder?` — stored optional relationship; on folder delete, **nullify** (scripts survive)
- `wordCount: Int` — **computed** from `content` (whitespace/newline-separated tokens). *Rationale: derived data stored twice can drift; scripts are small enough to compute on demand.*
- `estimatedReadingTime: TimeInterval` — **computed**: `wordCount / 150.0 * 60` seconds (**150 wpm**), displayed as `Xm Ys` (e.g. `4m 30s`; under 1 min shows `45s`). *Rationale: 150 wpm is the standard presentation speaking rate.*

**Folder** (SwiftData model)
- `id: UUID` — stored
- `name: String` — stored; new folders default to `New Folder`, renameable inline
- `scripts: [Script]` — inverse relationship, delete rule nullify

## 5. Screens and navigation

1. **Sidebar (folders):** `All Scripts` + user folders; "+ New Folder"; rename/delete via context menu.
2. **Script list:** scripts of the selected sidebar item; search field; each row shows title, modified date, word count, estimated reading time; "+" to create; context menu: Duplicate / Move to Folder / Delete.
3. **Editor:** title field + full-height content editor; toolbar shows word count + reading time and a prominent **Start Prompter** (play icon) button.
4. **Prompter (full-screen):** scrolling text + auto-hiding control overlay (transport, slider, −/+, speed readout, gear for settings sheet incl. mirror, close/X). Esc or X returns to the editor at the same script.

Flow: Sidebar → Script list → Editor → Prompter (full-screen cover) → back to Editor. Implemented with the platform-standard three-column-collapsing split navigation on both platforms.

## 6. Acceptance checklist (definition of done)

QA verifies by building and driving the app in the iPad Simulator and on macOS. All items must pass.

1. `xcodebuild` of the single multiplatform scheme succeeds with zero errors for an **iOS Simulator (iPad)** destination.
2. `xcodebuild` of the same scheme succeeds with zero errors for a **macOS** destination.
3. Tapping "+" in the script list creates an `Untitled` script that appears in the list within 1 s, and the script (with any typed content) is still present after force-quitting and relaunching the app — with no Save button ever pressed.
4. Typing 300 words into a script's content shows word count `300` and estimated reading time `2m 0s` in the editor toolbar; Duplicate on a script titled `Demo` produces a second script titled `Demo copy` with identical content.
5. Deleting a folder that contains at least one script shows a confirmation, removes the folder from the sidebar, and the script still appears under `All Scripts`.
6. In the prompter, pressing **Space** starts scrolling and pressing Space again pauses it with position retained; pressing **↑** once changes the numeric speed readout from 60 to 70 and **↓** returns it to 60; speed never goes below 10 or above 300 via any control.
7. At default settings, playback scrolls continuously to the end of a 1,000+ word script with no visible stutter or jumps, auto-stops at the end, and Stop resets the view to the top of the script.
8. Toggling **horizontal mirror** during playback flips the scrolling text instantly without stopping playback, while the control overlay and speed readout remain unmirrored and readable; the same holds for vertical flip and each rotation value (0/90/180/270), and all these settings plus font size and colors survive an app relaunch.
