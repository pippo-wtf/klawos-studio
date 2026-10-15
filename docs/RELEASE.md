# Local build and delivery

Version 0.1.14 targets Apple Silicon Macs with macOS 14+. Physical shortcut capture and live two-Mac sync still need acceptance; see [acceptance evidence](ACCEPTANCE.md).

## One installed app

The installed location is `~/Applications/KLAWOS Studio.app`. Quit Studio and KLAWOS Helper before updating, then run:

```
scripts/update-app.sh
```

This builds in a temporary folder, verifies the package and certificate identity, backs up the current app and saved data, replaces that same installed app, and refreshes only its background helper registration. It does not start Mac actions or write keyboard settings. Open Studio from your Applications folder afterward. No separate app is needed for each version.

Studio and its embedded helper use the same existing **Developer ID Application: Philip Scholl (D683769MKC)** signing identity on the Workbook. Normal builds require a usable Apple signing certificate. The script selects a unique Developer ID Application certificate first; if none exists it selects a unique Apple Development certificate. Set `KLAWOS_SIGNING_IDENTITY` to the chosen certificate's fingerprint when several certificates are available. The updater rejects a changed signing team, changed bundle identifiers, incompatible code requirements or temporary signatures before replacing an existing signed app.

The first move from the old ad-hoc build changes its permission identity. Studio and KLAWOS Helper may each need one final permission approval in System Settings. Subsequent updates must keep their location, identifiers, signing team and certificate family. Cryptographic identity continuity and file replacement have been tested; actual permission retention across two installed GUI builds remains a live acceptance check. No updater resets macOS privacy permissions.

Notarization and personal-MacBook transfer acceptance have not been completed. Do not disable Gatekeeper or copy permissions between Macs. The previous report that no valid certificate existed came from a restricted keychain check; the actual Workbook keychain contains a usable Developer ID certificate.

## Saved settings and recovery

App data lives at `~/Library/Application Support/KLAWOS Studio/`. The updater backs it up under ignored `configs/app-updates/<timestamp>/app-data`, with the previous signed app in `previous-app.zip`. These are private local backups. Keyboard transaction backups retain the last 20 completed transactions per definition plus unresolved recovery records.

To roll back, quit Studio and its helper, extract the chosen `previous-app.zip` into a temporary folder, then pass the extracted app to `scripts/app_update.py` using the bundled Python runtime. The same identity checks apply. Saved data is not automatically replaced with older data; restore its matching backup only if needed and after retaining the current data. Do not open an app directly inside a backup folder.

Saved Mac actions and extra layer names sync through iCloud Drive when enabled on both Macs. Physical keymap, macros and lighting travel with the keyboard. GitHub source access does not sync personal settings.

## Development and checks

`scripts/check.sh` runs the automated checks without live hardware writes. `scripts/build-app.sh` creates a certificate-signed build under `dist/build/`. Use `scripts/build-app.sh --development` only for an isolated temporary ad-hoc test build under `dist/development/`; it is not an installed update. Both commands refuse to build over the installed app.

`scripts/verify-package.sh "$HOME/Applications/KLAWOS Studio.app"` verifies bundled components, architecture and signature. The package includes native editor/agent/transport, Python 3.12.15, device service, local Three.js and GLB. No separate Homebrew, Vial, FreeMicro or Python installation is needed to run it. The source repository excludes the bundled runtime; use a complete app package on another Mac.

The helper is embedded as **KLAWOS Helper**, identifier `com.pippo.klawos.helper`. Its background service is `com.pippo.klawos.agent`, registered through SMAppService. It launches on demand; Mac actions require explicit Start. Closing the editor can leave the helper running. Updated helper executables are unregistered and registered again as required by SMAppService, without changing their signing identity.

To refresh the installed helper without reading or writing the keyboard:

```
"$HOME/Applications/KLAWOS Studio.app/Contents/MacOS/KlawosStudio" --refresh-helper-registration
```

The separate `--integration-check` reads the connected device and helper status. A permission result from this maintenance process does not establish the separately launched GUI's permission.

See [review repairs](REVIEW-REPAIRS.md) for recording and save changes. Use **Keys → select a button → Record shortcut** for a single-button shortcut; **Buttons together** is a separate advanced feature.

## Personal MacBook setup

After physical shortcut capture passes acceptance, publish a complete signed Apple Silicon app to the private GitHub release. On the M3 Pro MacBook, download and expand it, place **KLAWOS Studio.app** in `~/Applications`, and always update that same installed app using a signed package with a matching identity. A full second-Mac installer and update acceptance check remains pending.

Open it, connect the same KLAWOS over USB, and close Vial. iCloud Drive brings in saved Mac actions and custom layer names after Studio verifies the board identity and reserved Work key. Allow the helper in Accessibility and Input Monitoring on this Mac too, then turn on Mac actions and test one physical key. Apps and named Shortcuts used by actions must exist on both Macs.
