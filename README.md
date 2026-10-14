# KLAWOS

Project home: `/Users/philip.scholl/_WORK/KLAWOS`.

Pippo requested Vial installation on the Workbook and a new app based on the existing Micro Studio 3D configurator. He explicitly requested planning and questions before any app code, and asked that files be saved in his Work folder.

## Files

- `handover/`: the original iCloud transfer, copied unchanged and checked against its checksum list.
- `configs/KLAWOS-workbook-readback-2026-10-14.vil`: a fresh export from the connected keyboard. Its parsed contents exactly match the latest handover layout.
- `software/Vial-v0.7.5.dmg`: the official macOS installer from https://github.com/vial-kb/vial-gui/releases/download/v0.7.5/Vial-v0.7.5.dmg.
- `docs/DISCOVERY.md`: verified findings, provisional scope, and outstanding planning decisions.

Vial 0.7.5 is installed at `/Users/philip.scholl/Applications/Vial.app`. It opened and displayed the connected `KLAWOS KLAWOS`. The installer is an Intel build; the Workbook already has working Rosetta. The upstream bundle is unsigned; no security controls were changed.

The separate-app approach is approved. Full planning documents are complete for review:

- [Specification](docs/SPEC.md)
- [Build plan](docs/BUILD-PLAN.md) — 13 ordered implementation tasks
- [Planning review](docs/PLAN-REVIEW.md)

The hardware reference is received: four real-device photos and two website screenshots, saved under `reference/hardware/2026-10-14/`. Read the [hardware reconstruction brief](docs/HARDWARE-REFERENCE.md). Spec/build-plan revision 1.1 incorporates the gold knob and transparent keys; previous planning documents are preserved under `docs/history/`. Implementation is explicitly on hold until he asks to code. No new app code, dependencies, helper, private repository, or keyboard mappings have been created by the planning work.

## Development status

Pippo authorized implementation on 14 October 2026 with “ok go on”. Work is local on `codex/klawos-studio`; no private remote or released app exists yet.

The project-contained runtime is `runtime/python/bin/python3.12`; do not use or modify the FreeMicro environment. Run fixture tests with `PYTHONPATH=service runtime/python/bin/python3.12 -m unittest discover -s service/tests -v`, native tests with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path native`, and boundary tests with `node --test tests/ui/contracts.test.mjs`. These tests do not access the keyboard.
