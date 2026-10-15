# UI/UX repair execution

Approved scope: all 17 findings in the UI/UX audit, same installed signed app, followed by independent UI and UX re-review. No admin/system-setting step is planned; notify the owner in advance if one becomes necessary.

1. Preserve app-specific fallbacks and exceptions; make keyboard restoration explicit; state-aware helper controls. Owner: binding implementer, host-actions and focused new module/tests.
2. Shared fields, button groups, checkbox rows, readable contrast and responsive layout; state-aware lock controls. Owner: UI implementer, styles and device-tools/tests.
3. Escape-aware input testing with unchanged normal recorder cancellation. Owner: recorder implementer, focused native recorder and session/tests.
4. Parent integration: macro numeric waits; slot assignment/usage; dedicated manual knob controls; unified inspector and contextual tests; explicit lighting autosave and restore; readable save outcomes; selection semantics and view switch.
5. Run focused failing-then-passing regressions, full checks and signed package checks. Preserve board revision and owner drafts during installation; resume existing helper state.
6. Inspect all pages at normal and minimum window sizes in installed app. Independent UI and UX agents re-review; repair findings and repeat relevant checks before completion.

Ruling: existing approved audit and repair order are the implementation brief. No extra design-approval round is needed because the owner explicitly authorized all listed repairs.
Ruling: unsupported keyboard fallbacks must be rejected with a clear choice; never invent a default that disables the key. No new action schema is needed.

## Verification ledger

- Exact project root write/read/remove preflight passed.
- Initial tracked source is clean at 3b01257; existing audit document is untracked and preserved.

- All 17 original findings implemented and independently re-reviewed. UI and UX passed within their documented scope.
- Independent correctness review additionally reproduced and closed late recording-context capture, held-modifier fallback conversion and stale save-preview races.
- Full checks: 107 Python + 88 Swift + 80 JavaScript = 275 passing tests. Focused RED failures were observed before behavior fixes. Final copy/layout checks retained all protections.
- Installed 0.1.16/build18 into the canonical signed app; both input permissions retained. Sixteen owner draft edits and saved helper configuration remained byte-identical. Mac actions restored to on.
- Native normal 1280x888 and minimum 880x640 inspection covered all twelve pages; separate UI reviewer inspected all 24 screenshots and the final spacing correction.
- Actual installed Escape test received Escape without changing assignments (Mac keyboard via CUA; not a physical KLAWOS press). No keyboard mapping or lighting writes were made for acceptance.
- See 2026-10-15-ui-ux-re-review.md for evidence and remaining acceptance boundaries.
