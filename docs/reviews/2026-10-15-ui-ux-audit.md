# KLAWOS Studio — UI and UX review

15 October 2026 · Studio 0.1.15/build 17 · source revision `3b01257`

**Assessment: FIX BEFORE DESIGN SIGN-OFF.** The screenshot exposes shared form and action-group problems. The UX review also found behavior that changes assignments unexpectedly. Fix the behavior first, then apply a consistent component system across all pages.

Two independent design agents reviewed UI and UX separately. The parent checked the running app and all twelve pages. This was an audit: no product code, keyboard assignments, lighting values or permission settings were changed. This report is the only new project file.

## Scope and evidence

- **Visual evidence:** the supplied Keys inspector screenshot; live Keys, Keyboard settings, Lighting, Mac actions and About keyboard screenshots. The actual app confirms touching button borders, inconsistent native select sizing and checkboxes below their labels.
- **Live inspection:** all twelve pages were opened. Fields and state were read; save, recording, lighting adjustments, unlocking, helper start/stop/restart and recovery actions were not exercised.
- **Isolated interaction probes:** the UX agent ran actual UI functions in an in-memory DOM to reproduce the app-context fallback, profile deletion and macro Wait defects. These probes did not touch the app or device.
- **Source evidence:** field construction, action routing, save review, recording cancellation, CSS geometry and contrast were inspected. Contrast calculations were independently checked by the parent.
- **Limits:** minimum-size window rendering, VoiceOver, hardware output for the proposed corrections, and recovery with a real interrupted transaction were not tested. No new full test-suite run was needed for this read-only audit. The earlier 236 passing checks did not cover these visual and interaction cases.

Priorities: **P1** changes behavior unexpectedly and should be fixed first; **P2** blocks a specific operation or causes substantial confusion; **P3** is lower-impact consistency work.

## UX findings

### UX01 · P1 · An app-specific action silently removes the normal fallback

**Trigger:** Start with an ordinary keyboard key, choose “When using → Claude,” and add an action. The new profile sets “All other apps” to “Do nothing.” The key consequently loses its previous behavior outside Claude. **Reproduced in memory.**

**Fix:** Keep an explicit fallback. Preserve the previous keyboard behavior where supported; otherwise require the user to choose the fallback before saving. Display it beside the app exception.

Evidence: [host-actions.js:17](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:17).

### UX02 · P1 · Returning to keyboard mode removes app exceptions and leaves a trigger code

**Trigger:** Select “All other apps → Use keyboard action” on an app-action key. The whole profile is deleted, including app-specific exceptions. On an installed app button, its reserved F-key remains as the ordinary keyboard assignment. **Reproduced in memory.**

**Fix:** Separate changing the default action from removing every app action. Returning to keyboard mode must require a real key assignment or restore a known previous assignment; it must not silently leave the internal trigger.

Evidence: [host-actions.js:17](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:17), [app.js:35](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:35).

### UX03 · P2 · Macro Wait values cannot be edited

Changing Wait from 100 to 200 calls `.split()` on a numeric value. The UI reports “v.split is not a function” and retains 100. **Reproduced using the actual input and macro editor functions.**

**Fix:** Handle numeric waits before parsing key lists; validate the duration and give a readable error if needed.

Evidence: [app.js:17](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:17), [app.js:72](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:72).

### UX04 · P2 · Lighting contradicts the save model

The app initially says changes stay on this Mac until “Save to keyboard.” Lighting instead applies immediately and saves after a short pause. The live Lighting page gives no advance autosave notice. “Discard changes” cannot undo lighting already saved to the board. **Code-confirmed; page wording checked live.**

**Fix:** Clearly label Lighting “Changes apply and save immediately” before the controls, with a real undo/restore option. Keep its status separate from unsaved keyboard edits.

Evidence: [index.html:3](/Users/philip.scholl/_WORK/KLAWOS/ui/index.html:3), [app.js:82](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:82), [live-lighting.mjs:13](/Users/philip.scholl/_WORK/KLAWOS/ui/live-lighting.mjs:13).

### UX05 · P2 · Escape cannot pass the recording-based button test

Escape stops native recording before the key is captured. Both “Record shortcut” and “Test this button” use that recorder, so an Escape button cannot be received successfully through that test. **Code-confirmed; no physical Escape test was run.**

**Fix:** Treat Escape as input when testing. Explain cancellation when recording, and retain an obvious way to assign Escape.

Evidence: [ShortcutRecorder.swift:51](/Users/philip.scholl/_WORK/KLAWOS/native/Sources/KlawosContracts/ShortcutRecorder.swift:51), [app.js:40](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:40), [recording-session.mjs:20](/Users/philip.scholl/_WORK/KLAWOS/ui/recording-session.mjs:20).

### UX06 · P2 · The inspector has competing action models and an incomplete test path

Keyboard entry, recording, inheritance, “Do nothing,” testing and a second action menu compete in one column. App-action buttons hide the keyboard test, while their actual actions pause when Studio is in front. The user has to infer how to test the result. **Screenshot and live UI confirmed.**

**Fix:** Begin with one clear action choice: Keyboard, Open app, or Other Mac action. Show only relevant fields, one current assignment and its save state. Give app actions a test path that explains leaving Studio.

Evidence: [app.js:32](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:32), [app.js:45](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:45), [host-actions.js:39](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:39).

### UX07 · P2 · Macro and Tap & hold editors stop before assignment

Both editors let users create slots but provide no “Assign to a button” action or “Used by…” information. Assignment remains possible through the Keys catalog; this is a missing guided workflow, not an impossible operation. Their selectors also retain generic “Item 1” names. **Live and source confirmed.**

**Fix:** Name slots by function, show where they are used, and provide an assignment picker with layer and button selection.

Evidence: [app.js:70](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:70), [app.js:71](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:71), [app.js:72](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:72).

### UX08 · P2 · The knob can erase the navigation it promises

The knob is presented as the manual Work/Dota/Wardogs switch, but its inspector permits ordinary remapping, “Do nothing” and inheritance. These can remove the control the navigation model relies on. **Code-confirmed design risk; no knob edits were made.**

**Fix:** Give the knob a dedicated mode-switch section. Put remapping behind an explicit advanced choice explaining the effect. Keep switching manual.

Evidence: [app.js:35](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:35), [app.js:38](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:38), [app.js:46](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:46).

### UX09 · P2 · Save review can bring back hidden internal codes

The helper prepares reserved F-key assignments, and the save review renders all hardware changes alongside app-action rows. A new app assignment can therefore show both an internal F-key change and “Open Codex.” **Code-confirmed; consistent with the earlier live assignment review.**

**Fix:** Review the outcome as “Work · Key 12 → Open Codex.” Put transport codes in optional technical details rather than the normal confirmation.

Evidence: [HelperRuntime.swift:67](/Users/philip.scholl/_WORK/KLAWOS/native/Sources/KlawosAgent/HelperRuntime.swift:67), [app.js:107](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:107).

### UX10 · P2 · Controls do not reflect the current helper state

The live Mac actions page says actions are paused and both permissions are enabled, yet offers Allow access, Turn on, Turn off and Restart together as enabled peers. “Turn on” cannot resolve the automatic foreground pause. Keyboard lock similarly offers both lock and unlock regardless of its reported state. **Live helper page and source confirmed; no state-changing buttons were pressed.**

**Fix:** Use one state-aware main action. Explain temporary foreground pausing separately. Show permission setup only when needed, and move Restart into troubleshooting.

Evidence: [host-actions.js:39](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:39), [host-actions.js:41](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:41), [device-tools.js:8](/Users/philip.scholl/_WORK/KLAWOS/ui/device-tools.js:8).

## UI findings

| ID / priority | Verified problem | Recommended correction |
|---|---|---|
| **UI01 · P2** | Labels and selects run together in “When using” and “Action.” `field()` places the select directly after label text. Screenshot and live inspector confirmed. [host-actions.js:8](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:8) | One reusable field component: stacked label, 6px gap, full-width control. |
| **UI02 · P2** | Related buttons have no group spacing. “Use lower layer,” “Do nothing,” and testing touch; Mac actions and export buttons repeat the problem. Screenshot and live pages confirmed. [app.js:35](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:35), [host-actions.js:41](/Users/philip.scholl/_WORK/KLAWOS/ui/host-actions.js:41), [app.js:89](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:89) | Explicit wrapping action rows with 8px gaps and 12–16px separation from fields. Separate assignment choices from testing. |
| **UI03 · P2** | Native selects are visibly shorter than adjacent inputs/buttons. The global CSS has no shared control height or deliberate select styling. Screenshot and live Lighting confirmed. [styles.css:1](/Users/philip.scholl/_WORK/KLAWOS/ui/styles.css:1) | Consistent 36px minimum control height, padding and radius; verify native WebKit rendering. |
| **UI04 · P2** | Keyboard-settings checkboxes appear below labels, making rows unnecessarily tall. The flex rule targets the label, but the input is its sibling. Live screenshot and source confirmed. [app.js:15](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:15), [app.js:88](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:88) | A dedicated checkbox row containing input and label, aligned with an 8px gap and shared click target. |
| **UI05 · P2** | Important small text is faint. Calculated contrast: inspector hints 3.13:1; captions 2.71:1; footer 3.12:1; focus outline against white 2.45:1. The screenshot confirms difficult-to-read hints. [styles.css:1](/Users/philip.scholl/_WORK/KLAWOS/ui/styles.css:1) | Darken small supporting text toward a 4.5:1 target, and make focus indicators clearly visible. Use spacing and weight for hierarchy. |
| **UI06 · P2** | Current section and selected key are expressed with CSS classes without corresponding accessible current/selected state. Code-confirmed; VoiceOver was not tested. [app.js:20](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:20), [app.js:64](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:64), [app.js:65](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:65) | Synchronize accessible state with visible selection; distinguish page navigation from key selection. |
| **UI07 · P3** | The 3D / Top buttons do not show which view is selected. Code-confirmed. [app.js:67](/Users/philip.scholl/_WORK/KLAWOS/ui/app.js:67) | A segmented view control with visible and accessible active state. |

## Recommended shared design rules

Use spacing tokens of **4, 8, 12, 16, 24 and 32px**. Start with **24px panel padding, 24px between sections, 16px between fields, 6px between labels and controls, and 8px between related buttons**. Keep standard controls at least **36px high**. Use stacked inspector fields; reserve inline layouts for checkboxes and deliberately grouped actions. Give long forms a readable content width rather than stretching every field across the full page.

Use the same field, button-group, status, empty-state and review components across all twelve pages. Define disabled, loading, selected, saved and error states rather than relying on explanatory paragraphs to compensate for missing behavior.

## Repair and verification order

1. Repair UX01–UX03 with regression tests for fallback preservation, app exceptions, real keyboard reassignment and numeric waits.
2. Establish the shared field, checkbox and action-group components. Apply them to every page, including empty, loading and error states.
3. Finish the action-selection, assignment and testing flows. Make immediate lighting saves explicit. Keep manual knob switching protected and understandable.
4. Review actual outcomes in confirmation dialogs, then verify selection semantics, keyboard focus and readable contrast.
5. Visually verify all pages at the normal window size and native minimum **880×640**, including long labels, button wrapping and page scrolling. Check app-action testing outside Studio and regular keyboard recording separately.

## Coverage and retained limitations

Keys, Macros, Lighting, Tap & hold, Buttons together, Key replacements, Keyboard settings, Mac actions, Keyboard lock, Test keys, Restore and About keyboard were inspected live. Restore currently has no interrupted-save entries, so its populated recovery actions were reviewed in source only. Key testing was inspected but not started. Lighting sliders and permission controls were not changed. Current iCloud read failure was observed; diagnosis of that separate sync failure was outside this design audit.

What already works: editing a layer does not switch hardware mode; app-button labels show Open Codex/Open Claude; the normal app inspector hides reserved codes; saving has a review step; recording sessions protect against assigning late results to a different selected target. These should be retained during the repair.
