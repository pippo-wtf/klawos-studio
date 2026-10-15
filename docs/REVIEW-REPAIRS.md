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
