# G2 investigation — Workbook, 2026-10-14

Status: **decision pending; no input capture or suppression installed**. G1's vendor-interface readback succeeded, but that interface supplies configuration reports rather than per-key events.

The keyboard has a separate ordinary HID keyboard interface. Apple's [Quartz event field list](https://developer.apple.com/documentation/coregraphics/cgeventfield) exposes virtual keycode, keyboard *type*, event-source process/user data and other fields, but no physical HID device or registry identifier for a keyboard event. Apple describes [keyboard type](https://developer.apple.com/documentation/coregraphics/cgeventsource/keyboardtype) as the keyboard type used for translation, not the unique input device. A Quartz event tap can suppress an event, but its documented fields alone cannot decide whether identical F13 chords came from KLAWOS or another keyboard. This is an inference from the documented fields, pending a physical test.

IOKit identifies a specific HID keyboard interface for observing raw reports. Apple's [`IOHIDDeviceOpen`](https://developer.apple.com/documentation/iokit/1588670-iohiddeviceopen) documents exclusive seize; the installed SDK `IOHIDKeys.h` says this prevents the system and other clients from receiving *events from the device*. Seizing the whole keyboard interface and re-emitting every ordinary and gaming key would change latency and input behavior, contrary to the approved build plan. Observing reports without seizure does not remove the corresponding system keystroke.

QMK's [Raw HID](https://docs.qmk.fm/features/rawhid) can send a device-specific message to a host, but this requires a firmware handler. No suitable KLAWOS firmware source or safe flashing procedure has been verified. It cannot be treated as a Vial mapping change.

Current `CGPreflightListenEventAccess()` returned `false` and `CGPreflightPostEventAccess()` returned `true` for the development process. We did not request or grant Input Monitoring. No physical key test, helper trigger mapping, game-key interception, or synthetic injection has occurred.

Possible decisions:

1. Reserve uncommon F13–F24 chords system-wide while the helper is active. This enables the Mac actions on current firmware but also intercepts the same chord from another keyboard. The action can still follow the frontmost app. The approved strict device-isolation acceptance test must be revised explicitly.
2. Obtain and verify KLAWOS firmware source, then design a Raw HID action channel and cautious flash/recovery procedure. Device-specific host events are possible in QMK, but feasibility for this physical board is unknown.
3. Keep the strict criterion and leave helper action routing paused. Continue device configuration features independently.
