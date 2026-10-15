# Live lighting — 14 October 2026

Lighting controls update the keyboard as the slider moves. Requests run one at a time and queued intermediate positions are replaced with the latest position. After 400 ms without input, the final setting is saved to the keyboard. Effect, color, intensity, brightness and speed use this path; unrelated key edits remain drafts.

The dedicated service operation validates the existing snapshot, device connection generation, UID, protocol, lighting limits and expected current lighting. It sends only RGB packets, verifies readback, and saves lighting memory only after settling. Changed external lighting or failed readback stops the operation. The editor pauses conflicting controls while updates are pending. Helper revision metadata follows successfully saved lighting without changing action bindings or starting Mac actions.

Verification: 72 Python, 56 Swift and 14 JavaScript checks passed (142 total), including lighting-only packets, external-change conflicts, wrong-device rejection, failed readback, queue coalescing and failure stopping. Package and signature checks passed.

Live packaged UI: changed Color from 133 to 128 without clicking Save. Direct keyboard readback returned 128, with effect 3, speed 63, intensity 18 and brightness 71 unchanged; the UI showed Lighting saved. Restored Color to 133 through the slider. Full keyboard readback returned the same revision as before the test: e8640055e4ed77121a6c3738c32f589fe873455b4520523240179f0fbec883c8. This establishes settings readback, not visual inspection of the physical LEDs or a power-cycle persistence test.

The app is open on Lighting. Mac actions remain off because the helper reports Accessibility and Input Monitoring permissions off; lighting does not require those permissions.

## Physical color check — 15 October 2026

With KLAWOS connected to the Workbook, Studio changed VialRGB mode from 3 (Alphas Mods) to 2 (Solid Color), then raised saturation from 18 to 253 and brightness from 71 to 202. The owner confirmed that the physical keys changed color or brightness. Studio reported that lighting was saved; its service verifies device readback before reporting success. A separate direct keyboard write then restored the exact original mode 3, speed 63, HSV [106, 18, 71], and a fresh Studio read showed the same values. This confirms the board can respond visibly to live Studio lighting changes. The test did not establish that every effect uses the color slider in the same way.

Studio 0.1.6 now displays Vial's effect names and explains that Solid Color is the choice for one clear color across the keys. The 3D model remains an unlit preview and is labelled accordingly.
