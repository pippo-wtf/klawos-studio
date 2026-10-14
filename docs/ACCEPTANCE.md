# KLAWOS Studio acceptance — 14 October 2026

Status: local development build, not a completed two-Mac release.

On 14 October 2026 the Workbook helper showed Accessibility and Input Monitoring enabled and was started. A physical top-left Work-key press produced one press, one release and a `Done` action result; TextEdit was running, and Pippo confirmed that TextEdit opened. This accepts that one Mac-action path on the Workbook. Other action types, hold/repeat behavior and the personal MacBook still need physical checks. Automatic iCloud sharing of Mac actions and extra layer names has been added in source; its real two-Mac transfer is not yet verified.

## Verified on Workbook

- Bundled Python 3.12.15 imports its device service without a system Python dependency.
- Native window launches; local bundled JavaScript initializes through a restricted asset scheme.
- The editor reads the physical KLAWOS through the bundled native transport. Six layers, 100 macros, 2845 macro bytes, 32 tap dances/combos/overrides, 21 settings, VialRGB and exact string UID are present.
- A draft top-left edit from A to B left the physical key at A, established by an independent readback.
- Native app Apply preview showed only A → B. Apply backed up, wrote, and verified B. The same UI restored A.
- A final independent complete read found **all hardware and lighting exactly equal** to the pre-test snapshot. Knob TO(1)/TO(2)/TO(0) remains intact.
- Service-managed XPC editor/helper communication and packaged read-only device access passed. The helper authenticates the editor executable path and running code signature.
- At the initial check, the helper reported Accessibility=false and Input Monitoring=false. Both were later granted and verified true.
- Initial native 3D rendering and control list were visible, including a gold knob and transparent caps. Subsequent GLB export has topology tests; its final visual review is pending.
- Macro and lighting tabs were inspected. A hue-slider clamp display bug was found and fixed; final visible confirmation remains pending because the Mac locked.
- No automatic Work/Dota/Wardogs selection is implemented. Layer selection in the editor is draft inspection only.

## Implemented but not fully physically accepted

- General feature serializers; advanced editors; physical unlock and live matrix tester.
- Recovery drafts, pre-write backups, last-20 completed backup retention plus unresolved journals.
- Foreground-only macro recording, Escape/Stop/end-on-focus-loss, release cleanup.
- Per-app action bindings, reserved F13–F20 allocation, explicit mappings required on other layers, explicit helper Start/Stop, Vial/disconnect/permission suspension.
- Typed shortcuts, installed-app launch, named macOS Shortcuts, exact enabled menu paths.
- Native project import/export, Vial export backend, redacted diagnostics.
- Editable Blender source, self-contained GLB, procedural fallback and accessible control list.

## Remaining acceptance / delivery gates

1. Unlock this Mac and finish native UI verification of the latest build, especially GLB, import/export, recovery, recording, keyboard-only use and minimum-size/200% zoom.
2. Continue physical repeat, focus-change, unplug, helper-off gaming and other action tests. One Work-key → TextEdit path passed on the Workbook; full G2/G3 acceptance is not yet claimed.
3. Verify representative advanced feature writes and lighting persistence after reconnect; a key save does not prove these families.
4. Review model appearance with Pippo. Reconstruction dimensions/materials are estimates.
5. Measure/install/test on the personal Mac. No remote access or second-Mac result is currently available.
6. Developer ID signing/notarization is not available in the checked keychain session. The current package is ad-hoc signed for local testing, not a notarized transferable release.
7. Final code review and private source publication are tracked separately; repository availability does not prove device acceptance.

## Explicit limitations

- Only unmodified F13–F20 have implemented macOS mappings. Modified reservations/F21–F24 remain disabled until their input gate is proven.
- Mac actions currently use ordinary Work keys; encoder Mac actions are not enabled. Encoders retain full hardware keycode editing.
- Firmware flashing and factory/QMK reset have no verified destructive recovery path and are not exposed as working operations.
- No per-layer LED API is claimed.
- Menu/app command readiness is checked against actual focus and availability; app-specific Codex/Claude candidate controls are not advertised as physically verified.
- The cause of the user's earlier unwanted switching was not conclusively identified. The new app does not perform automatic hardware layer switching.

## Final review and unlocked-Mac follow-up

Astra reviewed 435eab5 and identified five Important data-integrity issues plus one Minor integer-wire issue. All six were reproduced and fixed in c5ea002; the full suite passes with 64 Python, 56 Swift and 6 JavaScript tests. The source is published privately at https://github.com/pippo-wtf/klawos-studio (branch codex/klawos-studio).

The unlocked-Mac launch exposed a helper/editor bundle-identity collision. The helper is now a distinct embedded KLAWOS Helper.app with its own identifier. After refreshing this development registration, packaged XPC/device read succeeded and the real editor opened while the helper was running. The final GLB is visible with gold knob, clear/pale caps, black plate and silver body. Appearance still needs the owner's approval. Accessibility was visibly enabled; separate Input Monitoring setup is in progress. No new board writes were performed during review fixes.

### Physical setup follow-up

Both KLAWOS Helper permissions are now verified true. A real multi-key save exposed a validation-side UID representation mutation: all five written key values verified, but final equality falsely failed. Added a regression test and made validation copy its inputs (616d5db). The real Recovery → Complete intended changes → Apply path then succeeded without replaying key writes, installed the helper binding, and resolved the journal. The helper started successfully.

Current commissioning configuration: Work top-left is F13 → open TextEdit; Dota top-left remains its previous explicit key; previously transparent top-left entries on layers 2–5 explicitly use KC_A. Manual knob TO(1)/TO(2)/TO(0) and other keys are retained. Original complete backup: Application Support/KLAWOS Studio/backups/76f87e18-2e7b-4066-b28d-8318036140ce/before.json. The user chose to keep configuring the board; the Work top-left physical press has since passed.

The UI also exposes Vial export under Device, extra-layer names in portable project metadata, and Mac-action results in the helper panel. At this checkpoint, automated checks totaled 65 Python, 56 Swift and 7 JavaScript tests. These tests alone did not establish second-Mac or physical action acceptance.

At that package checkpoint, lighting hue visibly exceeded 100 (107), confirming the slider clamp fix; Device exposed extra-layer names and Vial export. The native Save dialog wrote configs/KLAWOS-final-ui-export.vil; all hardware fields exactly matched the independent device read and numeric UID remained exact. That package verified strict local signature and bundled runtime imports. Its SHA256 was c25a606bb6f0d6adf027ced619c7b169f3baf3f4e84a31de505a8415e0d4523b. Both helper permissions survived that update. The physical Work-key check passed later, as recorded above.
