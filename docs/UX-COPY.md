# App wording review — 14 October 2026

All twelve screens, native helper messages, save previews, and service errors were reviewed for plain English. Labels describe what happens: Save to keyboard, Test keys, Tap & hold, Key combinations, Mac actions, and Restore. Key names are readable while stored Vial codes remain unchanged. Errors give a next step without exposing internal paths. Advanced unknown values retain accurate numeric labels rather than invented meanings.

Verification: 68 Python, 56 Swift, and 12 JavaScript tests passed (136 total); JavaScript syntax and package verification passed. The rebuilt app was inspected on the connected keyboard across all twelve screens. A temporary Dota Key 2 change from 2 to A produced the expected before/after preview. During concurrent user interaction, that edit was saved. Further UI automation stopped when the user continued editing Dota keys; their pending edits were preserved. The test key has not been restored by the agent.

The updated ad-hoc-signed helper reported both Accessibility and Input Monitoring permissions off. Mac actions remain off pending permission setup. Physical key acceptance and second-Mac acceptance remain outstanding; this wording review does not establish those gates.

Terminology reference for advanced keyboard settings: https://docs.qmk.fm/tap_hold and https://docs.qmk.fm/features/auto_shift .

## Page context correction

The selected-key inspector is now present only on Keys with a connected keyboard. All eleven other pages clear and hide its controls and use the available width. Verified every tab in the packaged app through its accessibility tree, including returning to Keys; inspected the expanded Lighting page visually. No keyboard settings were changed. All 14 JavaScript checks and package verification passed.
