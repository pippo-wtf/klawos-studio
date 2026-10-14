# KLAWOS app — proposed approach

Approach A approved by Pippo on 14 October 2026: a separate KLAWOS app. This document preserves the approach discussion. The complete specification and build plan are now in `SPEC.md` and `BUILD-PLAN.md`. No app code, helper, private repository, or product dependencies have been created; implementation is explicitly on hold.

## Agreed direction

A separate KLAWOS configurator based on Micro Studio's selectable 3D board, covering every Vial feature supported by this keyboard. Deliver it on the Workbook and personal MacBook through a private repository and versioned app packages. Work actions automatically follow the active app. Wheel press continues to select Work, Dota, and Wardogs; Work rotation continues scrolling.

Pippo supplied four actual-device photographs and two website screenshots. They are saved and inspected; the gold knob and transparent keys in his photos are the appearance authority. See `HARDWARE-REFERENCE.md`. Model construction has not started, and dimensions inferred from images are estimates rather than measured CAD.

## Option A — reuse Vial's device logic beneath the Micro Studio-style editor

Recommended. Reuse the existing local 3D viewer/editor approach, adapt the pinned Vial device protocol and keycode logic behind an explicit service interface, and add a native Mac helper for richer Work actions. Keep the existing Micro installation and dirty source tree intact.

This best fits the requested interaction while preserving proven protocol behavior. The protocol layer is not already a standalone library: it imports Vial's Qt-based utility, unlock, and settings components. That coupling must be addressed explicitly rather than assuming the files can be copied unchanged. Preserve upstream license notices and ship required source/license material with releases.

## Option B — extend the Vial application itself

Keep its existing editor and add a 3D view and Mac helper. This starts closest to Vial feature coverage, but integrating the Micro Studio-style web editor into the legacy Qt application creates more UI and packaging work. Its current macOS release is Intel-only; the new delivery must be tested independently on both Macs.

## Option C — build all device communication afresh

Use an entirely new native protocol implementation and the reused 3D editor. This gives full control but requires reproducing and validating all keycode, macro, dynamic-entry, security, lighting, and firmware capability behavior. It has the highest compatibility burden and is not recommended for the first version.

## Proposed user flow for Option A

1. Open the app. It identifies the KLAWOS, reads its capabilities and configuration, and takes a local backup. Without the keyboard, open an explicitly labelled saved draft.
2. Choose Work, Dota, Wardogs, or another layer and select a key or wheel movement on the 3D board. A keyboard-accessible control list offers the same editing path.
3. Assign a standard Vial action or a Mac action. Work has Default, Codex, and Claude contexts. Runtime follows the foreground application; a separate editor selector lets the user inspect any context without changing runtime behavior.
4. Changes save into a local draft. Apply to keyboard shows the pending device changes, checks the device again, writes only the intended differences, and verifies by readback. Helper mappings are also staged and activated as one versioned configuration; they must not disagree with the keyboard's trigger mappings.
5. Advanced tools expose macros, lighting, tap dance, combos, overrides, QMK settings, matrix testing, import/export, keyboard-layout display, and security controls. Conditional features such as layout options, Alt Repeat Key, and firmware updating follow detected device capabilities. Unsupported controls explain why.
6. Export a Vial-compatible `.vil` for hardware mappings or an app project containing hardware mappings, lighting data, labels/icons, and portable Mac action profiles. Import is previewed and validated against the connected keyboard before writing.

## Runtime behavior

Follow the active application using its stable bundle identity, checking context again at the start of each action. Use Default Work outside Codex/Claude. Do not rewrite the hardware keymap on every focus change. Identify Mac-action triggers in Work and dispatch them through the helper; direct hardware bindings remain direct. The chosen input-capture/suppression mechanism is a feasibility gate, not an established capability.

The helper remains available when the editor window closes, has a visible status/quit control, and is installed without root. Each Mac establishes its own required permissions. It must not alter Claude/Codex hooks or protected agent configuration. A helper-dependent action must clearly report when the helper, target app, or permission is unavailable. Gaming actions and the hardware wheel/layer cycle must continue working when it is stopped.

## Early feasibility gates after planning approval

- Adapt Vial's transport boundary and read every supported feature on this KLAWOS without changing it. Compare the resulting layout with a fresh official Vial export.
- Prove the helper can route a chosen Work action from this physical keyboard exactly once, without stray keystrokes, ordinary-keyboard interception, or interference with Dota/Wardogs. Include modifier holds, rapid app switches, helper restart, and disconnection.
- Establish which app actions actually work in the installed Codex and Claude versions. Do not treat old Micro bindings as working merely because they are present in its config. Permission approval needs a current, identified prompt; no blind affirmative keystroke.
- Detect lighting support separately. Vial 0.7.5's `.vil` serializer omits lighting. The new project's backup must capture supported lighting reads as well as the `.vil` fields. Do not promise configurable layer-indicator colors from the global lighting selector.

If a gate fails, report the evidence and revise the affected design with Pippo before continuing; do not silently replace it with broader input capture or firmware changes.

## Save and recovery requirements

Vial writes individual settings sequentially. Apply is not an atomic device transaction. Re-read for concurrent changes, back up first, serialize device access, verify each stage, and compare the final readback. A cable removal or failed write produces a visible partial-save state, preserves the pre-write backup and draft, and offers reconnect/readback/recovery. Do not silently replay writes after a timeout.

Lighting persistence is explicit. UI-only colors/icons must be distinguished from colors actually applied to the keyboard. The six layers and all unrelated exported settings must survive narrow edits. Matrix testing is a user-started diagnostic view, not a permanent background polling mechanism.

## Delivery and acceptance

Bundle the required runtime: neither Mac should need the existing FreeMicro pipx environment, Vial installation, Blender, or a development checkout to run the finished app. Keep code/releases in the private repository; local permissions, credentials, and user data stay on each Mac. Use explicit project export/import rather than assuming repository access synchronizes settings.

Plan a release with a visible version, redacted diagnostic export, installer/update/rollback path, and signing/notarization checks. Required acceptance includes a clean install on both Macs, physical controls, app-aware Work actions, full supported-feature parity, `.vil` round trips, concurrent edits, disconnect/recovery, helper-off gaming behavior, and non-US keyboard-layout testing.

## Inspected source

Official Vial tag `v0.7.5`, downloaded for read-only inspection. Relevant files: `src/main/python/main_window.py`, `protocol/keyboard_comm.py`, `editor/keymap_editor.py`, `editor/rgb_configurator.py`, `editor/firmware_flasher.py`, `unlocker.py`, and `COPYING`. Source files carry `GPL-2.0-or-later` notices. The source archive is retained as reference material; it has not been executed or installed.
