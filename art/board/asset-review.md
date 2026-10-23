# Hardware model

Built from Pippo's appearance instructions and the supplied hardware references: 15 transparent caps, a gold diamond-knurled knob, silver case, black plate. Coordinates follow the verified 4×4 matrix with knob press at key:0:3. The two encoder directions have separate accessible UI controls.

`build_board.py` builds the editable `klawos.blend` and self-contained `ui/models/klawos.glb`. Blender 5.2.1 LTS generated this asset. The app has a procedural fallback and a control list if GLB/WebGL loading fails.

Dimensions, wall thickness, optical properties and underside details are estimates, not measured CAD. No desktop/photo background or image metadata is included in the asset. Blue/purple illumination in references is not represented as a firmware capability.

Topology tests pass. Initial procedural rendering was visually checked in the native app. Final GLB appearance and Pippo's approval remain pending; the Mac locked before that check.

## Rounded knob update — 23 October 2026

The approved icon and actual hardware photos guide a continuous low convex crown, without a flat inset or separate rim. The barrel and crown are now one smooth surface. Darker recesses contrast with the existing gold diamond knurl. The crown starts at height 1.16 and rises 0.14 to the existing 1.30 apex, on a 0.42-radius grip. These are visual proportions, not measured dimensions. No keys, case geometry, camera controls or hardware assignments were changed.

Both the editable Blender source/export and procedural Three.js fallback use the same profile. Blender 5.2.1 LTS rebuilt the `.blend` and `.glb`. The fallback has matching body/crown material regions.

Validation: existing model metadata/control-map tests passed; JavaScript syntax and UI contract checks passed. Independent geometry review found a closed outward-facing surface, valid normals, matching normals across the gold/recess boundary, and complete fallback material groups. All sixteen key IDs and eighteen control-map entries are preserved. Both model paths were visually checked; clicking the new knob in the installed app selected Press knob. The installed asset hashes matched the source, strict signatures passed with normal macOS certificate access, and the helper retained both input permissions. The screenshot gallery in `docs/SCREENSHOTS.md` was captured after this installation.
