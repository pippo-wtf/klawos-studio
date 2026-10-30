# Gold-knob app icon

Updated on 23 October 2026 with the built-in image generation tool in reference-based edit mode. The gold knob in the supplied hardware photos is the shape reference: a low, continuously rounded crown above a diamond-knurled cylindrical grip. The top has no flat inset or raised ring. The board model now uses a matching continuous low crown and darker knurl recesses; see `art/board/asset-review.md`.

Source: `ui/assets/gold-knob.png`. The existing `scripts/build-icon.sh` packages this shared artwork into the ten standard macOS icon representations (16–1024 pixels) in `dist/Klawos.icns`. Studio’s header, native app and About icons, and the embedded helper icon use this artwork.

## References

Local reference previews `actual-02.png`, `actual-03.png`, and `actual-04.png` under `/Users/philip.scholl/_WORK/KLAWOS/reference/hardware/2026-10-14/previews/` show the user's actual golden knob. These photos remain outside the repository. The reconstruction matches visible appearance; its dimensions are not measured CAD.

## Generation prompt

Use case: reference-based product icon reconstruction. Make a single isolated 3D golden rotary-knob app icon, faithfully based on the REAL GOLD KNOB in these three photographs of the user's keyboard. The photos are the authority for geometry, especially the low rounded top and tall knurled cylinder. Reconstruct only that knob, not the keyboard, desk, cable, keys, or base mounting plate. Very important correction: the top is smoothly rounded across its entire surface but LOW and gently convex, a shallow oblate cap. The cap rises only about 12% of the knob's full diameter above the sidewall, far less than a hemisphere. It must not have a high egg/ball/mushroom dome. It must also not be a flat disk with a beveled edge: there is a continuous subtle convex curvature from edge to center, no inset, no rim, no flat plateau, no border band. The knurled cylindrical body remains dominant, with roughly 0.8 diameter of sidewall height. Match the fine diamond-knurled grip, dark recesses, warm brass-gold ridges and satin brushed golden low crown seen in the hardware photos. Use clean premium realistic 3D studio rendering with curved soft highlights to reveal the subtle low rounded cap, not a concentric-starburst flat record appearance. Three-quarter view around 30 degrees above horizontal, so both the low dome profile and textured sidewalls are legible. Balanced centered square app-icon composition, object fills around 78% of canvas with generous clear padding. One coherent knob. Genuine fully transparent alpha background, clean transparent corners and space around the knob; no floor, no drop shadow, no tile, no text, no markings, no shaft, no additional objects. Preserve the real device's proportions and gently rounded crown. Do not exaggerate the dome height.

## Icon update verification

- Source checked as 1254 × 1254 RGBA, with fully transparent corners. The visible object remains inside the canvas.
- All ten standard icon representations built successfully; the 128-pixel icon was visually inspected.
- The staged update was copied from the installed app. Only the shared PNG, both ICNS resources and the expected signing files changed. All file-backed executable sections, service code, remaining UI files and board model matched the installed build.
- Package structure, bundled service import, and strict code signature verification passed. Both directions of the old/new signing requirements matched for Studio and Helper (team D683769MKC).
- Installed into the existing `~/Applications/KLAWOS Studio.app` with the updater's app/settings backup. Installed image and icon hashes match the project outputs. The helper reported Accessibility and Input Monitoring enabled after installation.
- Reopened Studio and visually verified the new low rounded knob in the header. This was an artwork-only update; no keyboard assignments or lighting settings were written.
