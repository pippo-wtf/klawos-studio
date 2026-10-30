# Hardware model

Built from Pippo's appearance instructions and the supplied hardware references: 15 transparent caps, a gold diamond-knurled knob, silver case, black plate. Coordinates follow the verified 4×4 matrix with knob press at key:0:3. The two encoder directions have separate accessible UI controls.

`build_board.py` builds the editable `klawos.blend` and self-contained `ui/models/klawos.glb`. Blender 5.2.1 LTS generated this asset. The app has a procedural fallback and a control list if GLB/WebGL loading fails.

Dimensions, wall thickness, optical properties and underside details are estimates, not measured CAD. No desktop/photo background or image metadata is included in the asset. Blue/purple illumination in references is not represented as a firmware capability.

Topology and control-map tests pass. See the dated visual checks below for the current model and rendering.

## Rounded knob update — 23 October 2026

The approved icon and actual hardware photos guide a continuous low convex crown, without a flat inset or separate rim. The barrel and crown are now one smooth surface. Darker recesses contrast with the existing gold diamond knurl. The crown starts at height 1.16 and rises 0.14 to the existing 1.30 apex, on a 0.42-radius grip. These are visual proportions, not measured dimensions. No keys, case geometry, camera controls or hardware assignments were changed.

Both the editable Blender source/export and procedural Three.js fallback use the same profile. Blender 5.2.1 LTS rebuilt the `.blend` and `.glb`. The fallback has matching body/crown material regions.

Validation: existing model metadata/control-map tests passed; JavaScript syntax and UI contract checks passed. Independent geometry review found a closed outward-facing surface, valid normals, matching normals across the gold/recess boundary, and complete fallback material groups. All sixteen key IDs and eighteen control-map entries are preserved. Both model paths were visually checked; clicking the new knob in the installed app selected Press knob. The installed asset hashes matched the source, strict signatures passed with normal macOS certificate access, and the helper retained both input permissions. The screenshot gallery in `docs/SCREENSHOTS.md` was captured after this installation.

## Crown lighting correction — 23 October 2026

The first screenshots still made the crown look flat. Read-only inspection confirmed that the running permanent app contained the current model and viewer, started after installation, and had no cached asset responses. The two directional lights put the strongest reflections at the rim in the default view; rotating the same model moved the highlight onto the crown and revealed its curvature.

The main light now illuminates the crown from behind, and a small locally generated softbox environment gives only the knob materials broader reflections. The low crown geometry and approved icon are unchanged. Temporary environment geometry is disposed after generation, and the reflection target is released with the viewer.

The default-view comparison visibly shows a low convex crown in both the packaged model and procedural fallback. Independent visual review found no blocking crown mismatch. The material remains smoother than the brushed surface of the icon; these are separate 3D and raster representations.

Installed verification: the permanent app displays the revised crown and “Beta Version.” Installed viewer, markup, model and icon bytes match the checkout. The stable signature verifies; both input permissions remain enabled, Mac actions are on, and the editor has zero pending changes. All six gallery images were recaptured from that app and cropped only to remove the 28-pixel macOS title bar.
