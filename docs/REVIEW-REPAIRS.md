# 0.1.11 review repairs

Repairs the 17 findings reviewed at 5fbfeb0. Physical shortcut output is an acceptance step, separate from these automated regressions.

| Findings | Changes |
|---|---|
| 1 | All shipped ChatGPT/Claude presets use the same restricted action schema at the native and device-service boundaries. |
| 2–3 | Late sync responses cannot replace edited drafts. Saves submit an immutable draft and lock editing until completion. Pending macro collection blocks preview/save. |
| 4–7 | Shortcut sessions are cancellable before Start replies, retain their original button/layer, restore controls on every error, ignore canceled native cleanup, and use modifiers held when the main key was pressed. |
| 8–9 | Unsupported mixed-side modifiers receive a clear error. Typing a key name is separate from explicit recording, which supports Shift-only chords. |
| 10–12 | Macro comparison normalizes equivalent grouping per slot. Full-buffer preflight rejects delimiter/escape corruption and unsupported text before writing. Firmware text macros currently accept printable ASCII; Enter/Tab use key steps. |
| 13 | Recovery dismissal uses an atomic durable marker and preserves damaged journal evidence. |
| 14 | Both local/cloud single-head conflict choices actually adopt or publish the selected settings. |
| 15–16 | Helper intent/execution checks prevent delayed starts/actions after Stop. |
| 17 | The editor and menu derive on/paused/off from current helper state. Editing a layer is never presented as the actual hardware mode. |

Single-button workflow: **Keys → select a button → Record shortcut → press/release the shortcut → Save to keyboard**. **Test this button** receives a foreground key event without changing assignments. The owner must press the intended physical KLAWOS button; the app does not attribute an ordinary macOS key event to a particular keyboard.

**Buttons together** is the advanced firmware combination feature. Its input buttons must already send its trigger keys; it is separate from assigning a shortcut to one button.

Automated tests include actual preset descriptors across save/export/import, serialized asynchronous UI flows, real Vial macro codecs, strict wrong-value rejection, durable recovery, both cloud conflict choices, and suspended helper actions. Live app installation, physical presses, and two-Mac iCloud transport require separate acceptance evidence in ACCEPTANCE.md.

## 0.1.12 — recording shortcuts already used by another app

The owner confirmed ordinary recording works, but left Control + left Option + D still triggered another app. The local NSEvent monitor ran after global shortcut routing. Explicit recording now uses an active session event filter and a temporary Carbon symbolic-hotkey mode, restoring only its own mode token. It runs only while Studio is in front and recording is active. Stop, Cancel, Escape, focus loss, permission loss, disabled filter, time limit, restart and teardown restore normal routing. A native 35-second deadline also ends an abandoned session when the web UI stops polling.

Studio checks its own Accessibility access before starting; the Helper's permission is a separate grant. If access or the active filter is unavailable, recording fails with instructions instead of silently recording an incomplete shortcut. Recording never changes another app's shortcut preferences. Existing left/right modifier history is preserved.

Six focused native tests cover the exact left Control + left Option + D sequence and cleanup/error paths without installing a real system filter. A deliberate passthrough mutation made the chord regression fail; the restored source passed. Complete checks: 92 Python, 83 Swift and 39 JavaScript tests. An independent read-only review returned PASS. These checks do not prove live interception of another app's registered shortcut; that still requires the owner's physical test with Studio's Accessibility access enabled. No claim is made about intercepting handlers installed earlier than Studio's session filter or protected system shortcuts.
