# Hardware model

Built from Pippo's appearance instructions and the supplied hardware references: 15 transparent caps, a gold diamond-knurled knob, silver case, black plate. Coordinates follow the verified 4×4 matrix with knob press at key:0:3. The two encoder directions have separate accessible UI controls.

`build_board.py` builds the editable `klawos.blend` and self-contained `ui/models/klawos.glb`. Blender 5.2.1 LTS generated this asset. The app has a procedural fallback and a control list if GLB/WebGL loading fails.

Dimensions, wall thickness, optical properties and underside details are estimates, not measured CAD. No desktop/photo background or image metadata is included in the asset. Blue/purple illumination in references is not represented as a firmware capability.

Topology tests pass. Initial procedural rendering was visually checked in the native app. Final GLB appearance and Pippo's approval remain pending; the Mac locked before that check.
