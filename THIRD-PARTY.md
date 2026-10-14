# Third-party provenance

Vial GUI v0.7.5: GPL-2.0-or-later; source archive hash is in build/manifest.json. The headless parser subset has now been adapted into `service/klawos_device/vial/`, with per-file original and adapted hashes in `build/vial-provenance.json`; its GPL license is copied there. Redistribution of a combined app needs a license review and corresponding source availability before any release.

Python 3.12.15 standalone: official astral-sh/python-build-standalone 20261013 release, arm64 macOS install-only build. Its verified digest is pinned in the manifest. Preserve bundled Python/dependency licenses when packaging.

Three.js 0.180.0: MIT; copied unchanged from the verified Micro Studio vendor directory into ui/vendor/three, including LICENSE. File hashes are recorded in build/three-sha256.txt. The board geometry and app UI are newly authored; the existing Micro source tree is unchanged.
