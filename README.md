# KLAWOS Studio

A separate native Mac configurator for Pippo's KLAWOS: a selectable 3D board, six-layer keyboard editing, Vial feature editors, verified saves and app-aware Mac actions.

**Current state:** a runnable local development build. The real keyboard read/edit/apply/restore flow and one physical Mac-action press on the Workbook have passed. Automatic iCloud settings sync is implemented but still needs a live check on the personal MacBook. See [acceptance evidence](docs/ACCEPTANCE.md).

## Run

Build: `scripts/build-app.sh`

Open: `dist/KLAWOS Studio.app`

Connect KLAWOS over USB and close Vial before reading. Edits stay in a draft until Apply. The knob's manual Work → Dota → Wardogs cycle is preserved; selecting an editing layer never changes the active hardware layer.

Mac actions need the helper's own Accessibility/Input Monitoring permissions and explicit Start. The current development input bank is F13–F20, reserved globally. Another keyboard sending the same chord triggers the same action. Do not treat an untested binding as accepted; see the physical gates in the acceptance document.

With iCloud Drive enabled on both Macs under the same Apple Account, saved Mac actions and extra layer names sync automatically. The board itself carries its keys, macros and lighting. Each Mac needs its own Accessibility/Input Monitoring permissions, and apps or named Shortcuts used by an action must exist there. Simultaneous edits pause sync until you choose which Mac's settings to keep. See [iCloud sync](docs/ICLOUD-SYNC.md).

The package bundles Python and local assets. No existing Micro Studio, FreeMicro configuration or protected MainBrain files are modified.

## Develop

`scripts/check.sh` runs Python, native and JavaScript tests without live hardware writes.

`scripts/verify-package.sh 'dist/KLAWOS Studio.app'` checks bundled components, architecture and local signature.

The architecture/specification and task history are in [SPEC](docs/SPEC.md) and [BUILD-PLAN](docs/BUILD-PLAN.md). [Release notes](docs/RELEASE.md) distinguish local signing from distributed release acceptance. [Third-party notices](THIRD-PARTY.md) document the adapted Vial GPL source, Python runtime and Three.js MIT assets.

Raw handovers, personal device backups, reference photographs, runtimes and builds are excluded from source control. The generated Blender/GLB assets contain hardware geometry only.
