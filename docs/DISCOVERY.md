# KLAWOS app — discovery and planning decisions

Date: 14 October 2026. Machine: Workbook, user `philip.scholl`.

This is the historical discovery record. Pippo approved the separate-app approach on 14 October 2026 and requested the full specification and build plan. `SPEC.md` and `BUILD-PLAN.md` now contain the complete planning documents; implementation remains explicitly on hold.

## Intended outcome

Install the KLAWOS configuration software on this Mac, then plan a new app based on the existing Macro/Micro 3D configurator. The user requires planning before coding and wants project files in his Work folder.

Confirmed scope: a separate KLAWOS app with Micro Studio's selectable 3D board and compact key editor, full supported Vial functionality, automatic active-app Work actions, and delivery to both Macs through a private repository.

## Verified current state

1. Read the vault handover `System/Handoff/2026-10-13_KLAWOS-workbook-transfer.md` and the transfer's `START-HERE.md`, `CONVERSATION.md`, and `WORKBOOK-HANDOFF.md`.
2. All seven entries in the transfer's `SHA256SUMS.txt` match on the Workbook.
3. Vial's official download page and upstream releases identify 0.7.5. Downloaded that macOS release and verified the disk image's internal checksum.
4. Installed Vial 0.7.5 in the user's Applications folder. Its window recognizes `KLAWOS KLAWOS` and offers layers 0–5.
5. macOS HID inventory reports KLAWOS VID 21057 (`0x5241`), PID 4660 (`0x1234`), including a raw HID interface with usage page 65376 (`0xFF60`) and usage 97 (`0x61`). This identifies the observed interface, not a tested custom-app transport.
6. Saved a fresh layout export through Vial. Parsed JSON is exactly equal to `KLAWOS-work-wheel-scroll-2026-10-13.vil`; no sections differ.
7. The exported device UID is `6994672159869375106`. Wheel press at matrix position row 0, column 3 is `TO(1)`, `TO(2)`, `TO(0)` on layers 0, 1, 2 respectively. Work encoder rotation is `KC_WH_U` / `KC_WH_D`.
8. Micro Studio exists at `/Users/philip.scholl/Applications/Micro Studio.app`, bundle version 1.0.3, build 4. Its source is `/Users/philip.scholl/Tools/padgui`; README reports editor version 0.8.2. These are different version surfaces.
9. Read the current Micro config at `~/.freemicro/keymap.json`. It mixes plain shortcuts, app launches, AppleScript menu actions, shell actions, and per-app overrides. No action was executed by reading it.
10. The existing padgui tree has many modified and untracked files. It is reference material; any reuse must preserve those changes and the working Micro installation.

Physical wheel behavior has not been tested by the agent. UI recognition and exported mappings do not prove physical presses or application behavior.

## Existing behavior to preserve

- Work → Dota → Wardogs → Work on wheel press.
- Work scroll wheel up/down.
- Current layout and original backup.
- Six device layers, even if the initial app names only the first three.
- Unedited settings, macros, tap dance, combos, overrides, and other exported fields.

The handover says the Work/Dota/Wardogs key layout is unfinished; the provisional Work layout in the transcript was never programmed. Current Micro bindings differ from older notes: for example, ACT06 is now Command palette rather than Approve. Plan from the live config rather than copying old notes.

## Reuse candidates

- Local Three.js board viewer, GLB asset-loading approach, camera controls, selection, icons, and keyboard-accessible control list.
- Compact key editor and clear capability/status explanations.
- Native macOS window and lifecycle approach.
- Safe diagnostics export, visible versions, and offline assets.

These are reuse candidates, not a final architecture. KLAWOS needs its own geometry, control map, configuration model, and device save/readback behavior. FreeMicro's Micro-specific writer and daemon cannot be assumed to support it.

## Confirmed feature scope — 14 October 2026

In response to the question about richer Mac actions versus keyboard-only shortcuts, Pippo answered: “yes it should. everything that is possible in the vial app.”

The planning scope is full Vial configuration coverage for features supported by the connected KLAWOS. Working interpretation of the “yes”: also include the richer Mac actions mentioned in the question. Keep native keyboard features and Mac-helper actions explicit in the design, because a helper is not part of ordinary Vial keymap behavior.

The saved device export has six layers, 100 macro slots, 32 tap-dance entries, 32 combo entries, 32 key-override entries, and 21 QMK settings. It has zero Alt Repeat Key entries; support is not established. Current Vial tabs expose Keymap, Macros, Lighting, Tap Dance, Combos, Key Overrides, QMK Settings, and Matrix tester. File import/export, keyboard-layout options, and security/unlock controls belong in the parity inventory as well.

The connected keyboard’s Lighting tab was inspected read-only in this session. It exposes an RGB effect selector (including Direct Control and Solid Color), color, brightness, speed, and Save. This view does not show configurable layer-indicator colors. No lighting setting was changed. Direct Control behavior has not been tested and must be inspected before defining its UI.

Some current Micro actions cannot be represented as ordinary keyboard shortcuts. Mac-helper actions need a separately designed runtime and permission flow. No helper has been installed or implemented.

Official references: https://get.vial.today/manual/ and https://github.com/vial-kb/vial-gui/tree/v0.7.5.

## Confirmed delivery scope — 14 October 2026

Pippo confirmed: “both macs. so a private repo would be good i guess”. Target machines are the Workbook and personal MacBook. Windows is outside the confirmed app-delivery scope.

Plan a private GitHub repository for source, version history, and packaged releases. It has not been created during planning. Confirm the authenticated owner and repository-name availability at creation time. No credentials, private logs, machine permissions, or live user configurations belong in the repository. Test fixtures should be deliberately sanitized.

Each Mac gets a double-clickable app and establishes its own permissions. Device-resident bindings travel with the keyboard; exported layouts and any app-specific action mappings need an explicit export/import design. Machine-specific paths and permissions cannot be assumed to transfer. A private repository alone does not provide configuration synchronization or app notarization.

The delivery plan must cover install, update, backup, rollback, visible version numbers, redacted diagnostics, and acceptance testing on both machines. Signing and notarization availability remain implementation-time checks.

## Confirmed Work-profile behavior — 14 October 2026

Pippo confirmed: “automatically follow the active app.” Work actions should resolve against the foreground application's bundle identity, with Codex, Claude, and Default Work contexts. The wheel's Work/Dota/Wardogs selection remains separate. The proposed design checks context at action start and avoids rewriting keyboard mappings on every focus change.

Pippo supplied four actual-device photographs and two website screenshots. All six were inspected and saved in `reference/hardware/2026-10-14/`. His gold knob and transparent keys take priority over website variants. `HARDWARE-REFERENCE.md` defines the reconstruction brief; dimensions and unseen geometry remain estimates.

Approach A in `APPROACHES.md` is approved. Pippo asked to finish the full spec and build plan and explicitly said not to start coding. Those documents are saved in `SPEC.md` and `BUILD-PLAN.md`; no app code or helper has been implemented.

## Configuration and asset inputs reserved for the build

- Which actions belong on the Work layer, and how should Codex and Claude differ?
- Where will Dota and Wardogs run, and what keyboard layout/operating system do those mappings target?
- Hardware image input received; model construction and visual acceptance remain pending implementation authorization.
- Design default: local drafts with an explicit Apply to keyboard and verified readback, specified in `SPEC.md`.

## Lighting boundary

The handover reports one global lighting control and an existing bottom-right layer indicator. Requested Dota red and Wardogs brown are not configured. KLAWOS-specific firmware source was not found in that earlier session. This session has not verified a new way to set per-layer indicator colors. Do not promise them in version one without current device/source evidence.

## Original planning sequence — now captured in the completed documents

1. Resolve the remaining usage/delivery questions and confirm the interpretation of richer Mac actions.
2. Inspect current Vial source and device capabilities read-only to establish feasible transport, backup, and verification behavior.
3. Compare two or three approaches and recommend the smallest one satisfying the agreed purpose.
4. Present the user flow, board/editor design, save/recovery behavior, capability limits, and acceptance checks.
5. Save a complete written specification for review in this folder.
6. After specification approval, save the detailed build/test/delivery plan for review.
7. Begin app implementation only after the user's planning requirements are satisfied.

## Required proof in the eventual plan

- Match the correct device and refuse incompatible exports.
- Read and back up before writing; re-read before applying if Vial or another app may have changed the device.
- Show partial-save/disconnection failure honestly and provide recovery from a verified backup.
- Confirm writes by readback, with separate physical-key and app-specific acceptance tests.
- Preserve the layer cycle, Work scrolling, extra layers, and unrelated exported fields.
- Test non-US keyboard layouts, reconnect, absent device, concurrent edits, and device access contention.
- Distinguish GUI preview colors from lighting actually supported by the keyboard.
- Deliver a double-clickable, versioned macOS app with redacted diagnostics and a defined install/update/rollback path.
