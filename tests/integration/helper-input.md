# G2 physical acceptance — pending

This procedure is not evidence of a pass. No event tap has been installed and no input permission requested; the narrow write/read/restore proof is recorded in docs/INPUT-GATE.md.

## Implemented offline evidence

- InputRouter: global allocated-chord routing, one dispatch per held virtual key, repeat consumption, matching release even after modifier changes, synthetic-event exclusion, explicit stop cleanup, configuration-generation invalidation.
- TriggerAllocator: deterministic Work matrix assignments, stable existing chords, conservative collisions across saved emission regions, unreadable/unknown-field refusal, exhaustion refusal, transparent-layer conflict refusal.
- MacInputEvent: SDK-backed F13–F20 decoding; unrelated keys and modifier-only events are not extracted. Tests create in-memory CGEvents; they never post them.
- Modifier-qualified chords and F21–F24 are disabled pending independent proof. Encoder allocation is not implemented. Arithmetic keycode expressions are refused, not partially evaluated. This is a conservative initial allocator, not full Vial feature acceptance.

## Outstanding before capture

1. User chooses the temporary Work key and resolves transparent gaming-layer preservation. Saved top-left mappings from the G1 snapshot are A, 1, transparent, transparent, transparent, transparent. Re-read before any write.
2. Implement and test the bounded native event-tap owner: explicit Start/Stop, timeout/disable cleanup, device-generation/disconnect checks, known Vial lifecycle suspension, permission-state handling. No action work inside the callback. No automatic permission grant.
3. Verify the exact running executable's Input Monitoring/Accessibility requirements and arrange user approval where macOS requires it. A development-process permission does not establish packaged-app permission.
4. Preview only approved changed fields; save a fresh pre-test export. Verified region writer/restore path must exist before mutation. Current probe intentionally rejects writes.

## Physical matrix (record counts, not raw key reports or typed text)

Test on Workbook, then repeat on personal Mac:

- Reserved chord from KLAWOS invokes exactly one action; key-up releases any held action.
- Same reserved chord from another keyboard invokes the same action.
- Hold/repeat, quick press/release, modifier-before-key, modifier-release-before-key, ordinary typing between triggers, Caps Lock, and focus changes.
- Own generated shortcut does not recurse. Other software-generated input needs an explicit acceptance result; marker-only exclusion is not universal synthetic-event detection.
- Ordinary shortcuts and gaming outputs remain unchanged. Validate transparent-layer resolution physically before materializing explicit keys.
- Stop, tap timeout/disable, permission loss, Vial launch, unplug/replug, agent crash/restart: reservations stop and pending held output is released without replay. Re-enable only after verified device/configuration generation.
- Simultaneous identical keys on two keyboards share a virtual-key state because Quartz provides no physical source identifier. Verify and document aggregate hold behavior; do not claim independent per-keyboard holds.
- Check macOS/application shortcut conflicts on each Mac. If a chord is taken, reallocate and repeat.
- Restore every temporary field, read back, and compare against the pre-test export. Keep backups if comparison fails.

G2 remains incomplete until these runtime checks are recorded. Unit tests cannot establish input suppression, permission behavior, disconnect cleanup, or both-Mac acceptance.

## Current procedure for the next authorized capture

1. Read `docs/INPUT-GATE.md` for live restoration evidence and the unresolved lighting discrepancy. Both user choices about the test key and gaming preservation are approved; do not ask them again.
2. Input Monitoring is the remaining OS access decision. With explicit authorization, run `KlawosProbe --request-input-permission` and have Pippo review the named app. Do not grant it automatically. Re-run `--input-preflight` after the user acts.
3. Quit Vial normally if it holds the device. Re-enumerate the device and save a fresh full snapshot to a new ignored configs filename using the worker. Do not reuse an old revision or a completed journal filename.
4. Run `KlawosProbe --key-input-proof PATH_TOKEN FRESH_BACKUP_PATH`. Tell Pippo when `input-test-ready` appears to press/release the top-left Work key three times. The window is 30 seconds. Keep the knob unchanged during this first narrow proof. Capture stops on disconnect or disabled tap. This harness counts events only; it does not prove actual application actions or all G2 cases.
5. Require `restored` plus a fresh independent full snapshot comparison, including lighting. Any discrepancy remains visible and blocks a complete-restoration claim. Preserve journals on error. Do not blindly repeat a write.

The general Apply coordinator, verified multi-layer resolution, official Vial lifecycle suspension, external-synthetic-event handling and both-Mac acceptance remain outstanding. The commissioning harness is not the finished helper.
