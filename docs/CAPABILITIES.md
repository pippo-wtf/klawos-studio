# KLAWOS capability and G1 readback evidence — Workbook, 2026-10-14

G1 **passed for read-only configuration** on the connected KLAWOS. `KlawosProbe` selected the vendor HID interface with VID `0x5241`, PID `0x1234`, usage page `0xFF60`, usage `0x61`, and this connection's registry path token `4295105283`. This path token is ephemeral; the Vial UID `6994672159869375106` identifies the definition, not a unique physical unit. A second matching pad must require explicit selection. The probe sent 156 guarded query packets and made no configuration writes.

The native readback at `configs/KLAWOS-native-readback-2026-10-14.json` was compared with a newly exported official Vial file at `configs/KLAWOS-vial-fresh-2026-10-14.vil`. After representing the UID as the exact integer required by `.vil`, **all 13 saved Vial fields matched exactly**, including 6 layer matrices, each encoder direction, 100 macro slots, layout options, tap dances, combos, key overrides, alt repeat entries, and settings. There were zero missing/extra hardware fields and zero unreadable settings. Both files are excluded from Git.

| Capability | Measured device value |
| --- | ---: |
| VIA / Vial protocol | 9 / 5 |
| Matrix | 4 × 4 |
| Layers | 6 |
| Encoder | 1, two directions per layer |
| Macros | 100 slots, 2,845 shared bytes |
| Tap dance / combo / key override | 32 / 32 / 32 slots |
| Alt repeat | 0 slots, unavailable in this firmware |
| QMK settings | 21 readable IDs, 1–21 |
| Feature flags | persistent default layer |
| Lighting | VialRGB protocol 1, 45 supported effects (0–44), maximum brightness 255 |
| Current lighting read | mode 3, speed 63, HSV [216, 93, 71] |

Lighting is absent from Vial's `.vil` export and is retained separately in the native snapshot. No per-layer RGB indicator behavior is exposed by the definition or readback. Caps Word and Layer Lock feature flags were not reported. Matrix dimensions include the knob press at row 0, column 3. The actual clockwise physical direction still needs a hand-turn check; the protocol's encoder slots were kept in their reported order.

The read-only boundary rejects every setter, unlock, reset, and unknown packet in both Python and Swift. It also checks exact 32-byte responses, an echo where the Vial protocol supplies one, finite query progress, and a selected physical generation. These tests and the field comparison establish a safe read adapter; they do not establish the later write, crash recovery, helper routing, or second-Mac gates.
