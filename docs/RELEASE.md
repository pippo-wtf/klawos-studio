# Local build and delivery

Version 0.1.2 is a development build for arm64 macOS 14+. It is not yet an accepted release on both Macs.

Build with `scripts/build-app.sh`; verify with `scripts/verify-package.sh 'dist/KLAWOS Studio.app'`. The app includes native editor/agent/transport, Python 3.12.15, device service, local Three.js and GLB. It requires no Homebrew, Vial, FreeMicro or Python installation to run.

The build script uses ad-hoc signing. The current keychain check found no valid distribution-signing identity. Do not disable Gatekeeper or copy permissions between Macs. Developer ID signing, notarization and a transfer test are still required for a verified distributed release.

App data is under `~/Library/Application Support/KLAWOS Studio/`. Drafts and helper configuration are private. Backups retain the last 20 completed transactions per definition plus unresolved recovery records. Saved Mac actions and extra layer names sync through iCloud Drive when enabled on both Macs; physical keymap, macros and lighting travel with the keyboard. GitHub source access does not sync personal settings.

The helper has its own embedded app identity (`com.pippo.klawos.helper`) and permission entry named **KLAWOS Helper**.

## Personal MacBook setup

The private GitHub release includes a complete Apple Silicon app. On the M3 Pro MacBook, download the `KLAWOS-Studio-macos-arm64-shortcuts-preview-0.1.2.zip` asset, expand it, and move **KLAWOS Studio.app** to Applications. Open it, connect the same KLAWOS by USB, and close Vial. The board carries its own keys, macros and lighting; iCloud Drive brings in the saved Mac actions and custom layer names after the app verifies the board identity and reserved Work key. Check **Mac actions** for the sync message. Allow **KLAWOS Helper** in Accessibility and Input Monitoring on this Mac too, then turn on Mac actions and test one physical key.

This is a private, ad-hoc-signed preview rather than a notarized release. macOS may require you to approve opening it in **System Settings → Privacy & Security**. Do not disable Gatekeeper. The source repository alone does not contain the bundled Python runtime, so use the complete release asset for manual installation.

The background service is `com.pippo.klawos.agent`, registered through SMAppService. It is launched on demand; no automatic Mac-action activation occurs. The menu bar offers Start, Stop and Open editor. Closing the editor can leave the helper running. KLAWOS controls no unrelated launch agents.

For local ad-hoc rebuilds, macOS may retain the previous code requirement. Use **Mac helper → Restart helper** after rebuilding. The development-only read check is:

```
'dist/KLAWOS Studio.app/Contents/MacOS/KlawosStudio' --integration-check --reset-agent-registration
```

That check refreshes only KLAWOS registration, queries helper status and reads the connected device; it does not write keyboard settings or grant permissions.

Before an update: export the project, Stop Mac actions, retain the previous app, and copy the matching Application Support data backup. Replace the app and restart its helper registration. Verify readback before enabling actions. Cross-version migration and rollback acceptance on both Macs are still pending; do not treat this procedure as a tested release result.
