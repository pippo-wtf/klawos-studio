# G2 investigation — Workbook, 2026-10-14

Status: **global reserved shortcuts approved by Pippo on 14 October 2026; runtime G2 proof still pending**. G1's vendor-interface readback succeeded, but that interface supplies configuration reports rather than per-key events.

The keyboard has a separate ordinary HID keyboard interface. Apple's [Quartz event field list](https://developer.apple.com/documentation/coregraphics/cgeventfield) exposes virtual keycode, keyboard *type*, event-source process/user data and other fields, but no physical HID device or registry identifier for a keyboard event. Apple describes [keyboard type](https://developer.apple.com/documentation/coregraphics/cgeventsource/keyboardtype) as the keyboard type used for translation, not the unique input device. A Quartz event tap can suppress an event, but its documented fields alone cannot decide whether identical F13 chords came from KLAWOS or another keyboard. This is an inference from the documented fields, pending a physical test.

IOKit identifies a specific HID keyboard interface for observing raw reports. Apple's [`IOHIDDeviceOpen`](https://developer.apple.com/documentation/iokit/1588670-iohiddeviceopen) documents exclusive seize; the installed SDK `IOHIDKeys.h` says this prevents the system and other clients from receiving *events from the device*. Seizing the whole keyboard interface and re-emitting every ordinary and gaming key would change latency and input behavior, contrary to the approved build plan. Observing reports without seizure does not remove the corresponding system keystroke.

QMK's [Raw HID](https://docs.qmk.fm/features/rawhid) can send a device-specific message to a host, but this requires a firmware handler. No suitable KLAWOS firmware source or safe flashing procedure has been verified. It cannot be treated as a Vial mapping change.

Current `CGPreflightListenEventAccess()` returned `false` and `CGPreflightPostEventAccess()` returned `true` for the development process. We did not request or grant Input Monitoring. No physical key test, helper trigger mapping, game-key interception, or synthetic injection has occurred.

Possible decisions:

1. Reserve uncommon F13–F24 chords system-wide while the helper is active. This enables the Mac actions on current firmware but also intercepts the same chord from another keyboard. The action can still follow the frontmost app. The approved strict device-isolation acceptance test must be revised explicitly.
2. Obtain and verify KLAWOS firmware source, then design a Raw HID action channel and cautious flash/recovery procedure. Device-specific host events are possible in QMK, but feasibility for this physical board is unknown.
3. Keep the strict criterion and leave helper action routing paused. Continue device configuration features independently.

## Approved decision

Pippo selected “Use reserved shortcuts globally (Recommended)”. SPEC.md 1.2 and BUILD-PLAN.md 1.2 supersede the previous strict physical-device isolation requirement. Only allocated chords are reserved, and identical chords on any keyboard deliberately invoke the same action. Active-app following remains required. No firmware modification is needed for this approach. Approval selects the design; it does not establish runtime correctness, grant macOS permissions, or authorize an unreviewed temporary physical mapping. G2 still requires physical validation on both Macs.

## Offline implementation checkpoint

InputRouter, TriggerAllocator and MacInputEvent now have passing offline tests. Native suite: 34 tests; Python suite: 36; JavaScript boundary: 1. No live capture or hardware writes occurred. The first native candidate bank is F13–F20, as defined in the installed HIToolbox Events.h; F21–F24 and modifier-qualified candidates remain disabled until proven. Encoder allocation and the event-tap owner remain outstanding.

The saved G1 snapshot shows top-left Work A, Dota 1, then transparent on layers 2–5. A Work trigger can therefore propagate through transparent layers. The allocator currently refuses affected assignments. Pippo has been asked whether to preserve verified gaming output with explicit cells or retain exact layer values and block conflicting helper actions. No answer has been assumed. See tests/integration/helper-input.md for the pending physical procedure and limitations.

## Approved live commissioning checkpoint

Pippo approved the top-left Work-key test and explicit transparent-layer preservation. Native commissioning performed A → F13 → A twice with readback after each change and an owner-only intent journal before each write. Every .vil hardware field matched each test's backup afterward. No gaming-layer preservation values have yet been written: the implementation requires verified resolved outputs and includes every preservation cell in the preview.

The first full comparison caught a VialRGB hue difference: 216 before, 208 after; mode 3, speed 63, saturation 93 and value 71 were unchanged. Pippo confirmed no intentional lighting edit. Two read-only snapshots remained at 208. Repeating the key round-trip did not reproduce any further change. Root cause is unresolved; do not attribute it confidently to firmware or hide it from acceptance evidence. An exact-value recovery command restored the backed-up runtime hue to 216. A complete subsequent readback matched identity, all hardware fields, lighting, capabilities, readability and the original revision. No lighting-save/EEPROM command was sent; persistence across power cycles is unverified.

Capture harness tests now cover disconnect cleanup, disabled-tap shutdown, ordinary-input pass-through and synthetic-marker exclusion. The 30-second physical window restores the original key afterward; it counts F13 events and does not execute application actions or record typed text. No live tap has been installed. Native 48, Python 36 and JavaScript 1 tests pass.

Actual probe preflight: Accessibility true; Input Monitoring false. Running the live-proof command refused before device enumeration or mutation with `input-permission-required`. Pippo has been asked whether to open the macOS prompt. No permission has been requested or granted by this work. After authorization, inspect the app named by macOS; do not silently grant a broader parent-app permission.

Private evidence is in ignored `configs/`: original before-test snapshot, round-trip and lighting-recovery journals, repeated-test snapshots and `KLAWOS-after-complete-restoration-2026-10-14.json`. Original and final revision: `f497364f6ad2fa18002a12a624c96aec658eb317577c8d45a7631f813779b6fa`.
