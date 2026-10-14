# G2 physical acceptance — pending

This procedure is not evidence of a pass. No event tap has been installed, no input permission requested, and no trigger written by this task.

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
