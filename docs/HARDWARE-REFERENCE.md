# KLAWOS — hardware reconstruction reference

Reference brief version 1.0 · 14 October 2026

Pippo supplied four photographs of his actual device and two website screenshots. All six were inspected. Reference gathering is complete for visible appearance; a model has not been built and implementation remains on hold.

## Appearance authority

Pippo's explicit instruction: “the knob is golden for in mine and the keys transparent.” His own photos take priority for this device's color, materials, and details. Website screenshots are secondary geometry/lighting references and show different knob/keycap variants.

| Saved reference | Source / use |
|---|---|
| `originals/actual-01.heic` / `previews/actual-01.png` | AA1F1241…: near-overhead photo, device rotated in the frame. Useful for cap spacing, outline, black inner plate and gold knob top. |
| `originals/actual-02.heic` / `previews/actual-02.png` | 0D1E1C61…: angled view showing keycap height/profile, transparent sides, visible switch bases, knurled knob and case depth. Primary angled appearance reference. |
| `originals/actual-03.heic` / `previews/actual-03.png` | 3069ACFF…: opposing angled view, useful for case rim, cap profiles, knob height and sidewall. |
| `originals/actual-04.heic` / `previews/actual-04.png` | 3D58DACC…: rotated port-side view showing cable/port cutout, rim relief, knob side texture and case silhouette. |
| `originals/website-transparent.png` | Screenshot 14.04.20: clear caps, silver knob, blue lighting. Secondary geometry reference; its silver knob is not Pippo's finish. |
| `originals/website-opaque.png` | Screenshot 14.04.29: opaque grey caps, silver knob and purple/red lighting. Secondary silhouette reference; its cap/knob colors are not Pippo's version. |

All paths above are relative to `reference/hardware/2026-10-14/` in the KLAWOS project. `manifest.json` records original basenames, saved paths, sizes, and SHA256 hashes. HEIC originals are copied unchanged; PNG previews are viewing conversions, not corrected/recolored evidence.

## Visible details to carry into the future model

- Fifteen square keycaps and one rotary knob occupy a four-by-four control footprint. The knob replaces one cap position; it is not an extra seventeenth control. Its press is the existing sixteenth matrix input.
- Transparent/translucent plastic keycaps with sloped sidewalls, rounded square shoulders and a recessed/dished top area. Internal round/cross switch features are visible through them; do not invent printed glyphs from those internal shapes.
- Gold/brass-looking knob with a rounded convex top and a cylindrical, diamond-knurled side. The recesses look dark in the real photos. Do not substitute the website's silver concave-top knob.
- Silver metallic-looking enclosure with rounded corners, substantial visible sidewall, a textured/chamfered-looking upper rim and a black inner plate/PCB area.
- Small gaps between the caps and visible switch/base details near the edges; avoid rendering fifteen completely opaque blocks.
- Cable/port cutout and local case relief are visible in actual-04. Do not treat the cable branding or desktop as part of the app's hardware asset. A cable is optional static context, not an interactive control.
- Actual photos show a blue/purple glow under/through the caps. It is photographed illumination, not proof of a fixed default hue, per-key control, state telemetry, or configurable layer-indicator colors.

## Orientation and control identity

Use a consistent app top view with the knob in the upper-right control position, matching the recorded wheel press at `key:0:3`; verify that physical orientation against the live device definition during the build. Photos rotate the device differently, so image axes alone are not matrix addresses. Use stable matrix and encoder IDs for model selection; do not infer firmware mapping solely from the image.

Wheel press and both rotations remain separately selectable. USB/case details are visual-only. Model/list editors must account for the sixteen matrix inputs and two rotation inputs without double-counting the knob.

## What remains estimated

Photos establish visible proportions and materials well enough to define the reconstruction brief. They do not establish millimeter dimensions, hidden underside/feet, internal construction, exact metal/plastic composition, or measured optical properties. Lighting and camera white balance affect the photographed colors. Exact dimensional fidelity would need dimensions or a source model; the intended app model is a reviewed visual reconstruction.

No new pictures are required to begin the planned visible-shape reconstruction once coding/model-building is authorized. Do not invent underside details and call them observed.

## Acceptance additions for the future asset task

1. Front/angled renders show transparent keys, a gold rounded-top knurled knob, silver case and black interior, using actual photos as the primary comparator.
2. The website's opaque-grey caps and silver knob are not copied into the personal variant.
3. Cap/internal detail remains legible with neutral preview lighting; no claimed live hardware color behavior is encoded in the material.
4. Every selectable matrix/encoder input opens the expected editor; the knob is counted once as a physical control with separate press/rotation inputs.
5. Side/depth/optical estimates are recorded in the asset review. Final visual fidelity still requires Pippo's review; receipt of these photos alone does not pass gate G4.

Keep raw originals/previews in local reference storage. Before any later repository inclusion, prepare deliberately selected hardware-only reference assets and remove unintended metadata/background details. No files have been uploaded or committed by this reference intake.
