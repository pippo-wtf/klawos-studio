# KLAWOS Studio 0.1.16 — UI/UX repair and re-review

15 October 2026 · build18 · same installed Developer ID signed app

**UI: PASS for UI01–UI07. UX: PASS for UX01–UX10 within the review scope below.** The two original independent reviewers repeated their reviews after implementation and installation. Their additional findings were corrected and checked again. A separate correctness reviewer also verified the three additional race/fallback fixes.

## Result

| Original findings | Change and verification |
| --- | --- |
| UX01–UX02 | Supported normal keyboard fallbacks survive app exceptions. Unsupported and held-modifier fallbacks require a real choice. Returning to Keyboard preserves exceptions and does not leave an internal trigger as the chosen key. Regression tests exercise mutation and non-mutation cases. |
| UX03 | Numeric macro waits parse before key lists and validate 0–65024 ms. Independent actual-editor probe changed 100 to 200 successfully. Text containing plus signs or commas stays text. |
| UX04 | Lighting announces immediate automatic saving before its controls. Restore returns to the values from page entry. Independent actual-function probe verified send, restore and enabled state without device writes. |
| UX05 | Button tests receive Escape as input; ordinary recording keeps Escape cancellation. An installed native test received Escape from the Mac keyboard and left settings unchanged. |
| UX06 | One action selector owns Keyboard, Open app and Other Mac action. Only relevant fields appear. App testing checks save/helper readiness and offers Hide Studio; keyboard testing is separate. Context/action changes cancel pending recording. |
| UX07 | Macro and Tap & hold slots have meaningful names, Used by information and guided layer/button assignment. Assignments stay in the draft until review/save; the knob is excluded. |
| UX08 | Knob mode switching has a dedicated section. Remapping is inside a warned advanced disclosure. Its test explains that mode switches emit no keyboard key and directs the user to compare a button with different assignments across modes. Switching remains manual. |
| UX09 | Save review describes human button outcomes rather than helper trigger allocation. Preview locks editing and retains its snapshot; Apply refuses a changed draft. |
| UX10 | Helper/lock actions reflect current state. Completed permission setup is hidden; helper restart lives under Troubleshooting. Keyboard unlock begins only after an explicit request. |
| UI01–UI04 | Stacked fields use 6px label gaps; related actions wrap with 8px gaps; controls have a shared 36px minimum; checkbox labels and inputs share one clickable row. |
| UI05 | Independently measured contrast: hints 5.87:1, captions 5.21:1, footer 5.65:1, focus 6.19:1. |
| UI06–UI07 | Navigation exposes aria-current; selected keys and 3D/Top expose aria-pressed with visible selection. View choice survives rendering. |

Re-review also corrected the Key replacements slot name, a remaining Buttons together CTA gap, the macro step-type accessible name, and an inaccurate reference to a nonexistent mode display.

## Verification

- Full checks: **107 Python, 88 Swift and 80 JavaScript tests pass (275 total)**. Focused failing regressions preceded behavior fixes; all existing recording, late-reply, save-lock, sync and draft-preservation assertions remain covered.
- Separate correctness review: **PASS** after reproducing and closing recording-context capture, held-modifier fallback conversion and stale preview submission.
- Independent UX focused run: 51/51; independent UI focused run: 29/29.
- All twelve actual installed pages reviewed at **1280×888** and native minimum **880×640**. Navigation, main content and inspector scroll independently. Final Buttons together gap rechecked at both sizes.
- The selected-key panel appears only on Keys. App buttons display Open Codex/Open Claude; no reserved trigger appears in their normal inspector.
- Signed ARM64 package, bundled Python/service and signature verified. Installed interface files match current source.
- Same app location: `~/Applications/KLAWOS Studio.app`. Existing Accessibility and Input Monitoring permissions remained enabled after replacement; no administrator or security-setting change was needed. Mac actions were restored to on after helper refresh.
- The owner's **16 draft edits were preserved**, not applied. Draft SHA256 remained `1d413f871063ac593be3066b3a765f7a32c62843e7bbcea293dd1bc3ddd20477`; saved helper SHA256 remained `fdec9234a29f0fab29c086be6a1e558c71d6b001612fd1e84b1e269ac84b3b0f`. Updater backups include the former app and app data under ignored `configs/app-updates/`.
- Actual native Escape test: “Received: Escape. Your settings are unchanged.” This proves installed input capture from the Mac keyboard via CUA, not physical KLAWOS output.

Local screenshot/accessibility evidence is archived under ignored `configs/ui-ux-review-2026-10-15/`; it is intentionally outside source control. Test/build logs live locally in `/tmp/klawos-*-check.log`, `/tmp/klawos-ui-final.log` and `/tmp/klawos-repair-build.log`.

## Acceptance boundaries

No keyboard assignments, lighting or permission settings were changed to obtain acceptance. Physical KLAWOS output/assignment and Mac-action execution outside Studio were not repeated for this release. The Hide Studio path's full saved-action execution remains a physical acceptance step; it refuses to test unsaved changes. VoiceOver operation, populated interrupted-save recovery and every offscreen form state were not exercised visually. The existing iCloud read warning remains a separate sync issue; this release does not claim a two-Mac sync pass. Package signing checks do not establish notarization.
