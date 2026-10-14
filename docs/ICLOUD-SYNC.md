# iCloud settings sync

KLAWOS's physical keymap, macros, knob behavior, and lighting live on the keyboard. Moving the board between Macs carries those settings. This sync covers the settings that live on a Mac: Work key actions (including Codex/Claude overrides) and extra layer names. It does not copy macOS permissions, local app installations, Shortcuts, credentials, drafts, backups, or raw device snapshots.

## Behavior

- Each Mac uses the same Apple Account's iCloud Drive folder, `KLAWOS Studio/Settings`, when iCloud Drive is available. No GitHub token or separate account is needed.
- A successful Save to keyboard publishes a portable settings revision. Name-only changes publish after their local draft is saved. Incoming revisions are checked against the keyboard UID and definition before they are used.
- On the other Mac, the helper reads the settings automatically. It applies Mac actions only after a live keyboard read proves that every reserved key already matches the board. It never rewrites the keyboard in response to cloud data. While the editor is open, it also refreshes the displayed names and actions.
- Each change is an immutable revision with a parent. If two Macs edit from the same older revision, sync pauses with a visible conflict instead of guessing which edit wins. Local settings and the board remain usable.
- Missing iCloud Drive and missing per-Mac Accessibility/Input Monitoring permissions are shown separately. iCloud Drive can queue changes while a Mac is offline, so the app cannot confirm that the other Mac has received a revision until it is opened there. Apps and Shortcuts used by an action must be installed separately on each Mac.

## Verification

Test clean first sync, second-Mac import, later edits in both directions, a simultaneous-edit conflict, malformed/foreign-device files, unavailable iCloud Drive, no-board state, and a reserved-key mismatch. Then install on the personal MacBook and check a real physical key on both Macs. This development build cannot claim two-Mac acceptance until that last test passes.
