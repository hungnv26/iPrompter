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
