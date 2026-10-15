#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
if [[ "${1:-}" == "--development" ]]; then
  shift
  identity=-
  app="${1:-dist/development/KLAWOS Studio.app}"
else
  identities="$(security find-identity -v -p codesigning)"
  identity="${KLAWOS_SIGNING_IDENTITY:-}"
  if [[ -z "$identity" ]]; then
    candidates="$(printf '%s\n' "$identities" | sed -nE 's/^[[:space:]]*[0-9]+\) ([A-Fa-f0-9]{40}) "Developer ID Application:.*$/\1/p')"
    if [[ -z "$candidates" ]]; then
      candidates="$(printf '%s\n' "$identities" | sed -nE 's/^[[:space:]]*[0-9]+\) ([A-Fa-f0-9]{40}) "Apple Development:.*$/\1/p')"
    fi
    if [[ "$(printf '%s\n' "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')" == 1 ]]; then identity="$candidates"; fi
  fi
  if [[ ! "$identity" =~ ^[A-Fa-f0-9]{40}$ ]] || ! printf '%s\n' "$identities" | grep -F -- "$identity" >/dev/null; then
    echo 'A stable signing certificate is missing. Install your Apple signing certificate first; no app was changed.' >&2
    echo 'If several certificates exist, set KLAWOS_SIGNING_IDENTITY to its fingerprint. Use --development only for an isolated temporary test build.' >&2
    exit 1
  fi
  app="${1:-dist/build/KLAWOS Studio.app}"
fi
resolved="$(runtime/python/bin/python3.12 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$app")"
if [[ "$resolved" == "$HOME/Applications/KLAWOS Studio.app" || "$resolved" == "$PWD/dist/KLAWOS Studio.app" ]]; then
  echo 'Do not build over the installed app. Use scripts/update-app.sh.' >&2
  exit 1
fi
swift build --package-path native
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Library/LaunchAgents"
cp packaging/com.pippo.klawos.agent.plist "$app/Contents/Library/LaunchAgents/"
cp packaging/Info.plist "$app/Contents/Info.plist"
scripts/build-icon.sh
cp dist/Klawos.icns "$app/Contents/Resources/"
cp native/.build/out/Products/Debug/KlawosStudio "$app/Contents/MacOS/"
helper="$app/Contents/Library/LoginItems/KLAWOS Helper.app"
mkdir -p "$helper/Contents/MacOS"
mkdir -p "$helper/Contents/Resources"
cp packaging/Helper-Info.plist "$helper/Contents/Info.plist"
cp native/.build/out/Products/Debug/KlawosAgent "$helper/Contents/MacOS/"
cp dist/Klawos.icns "$helper/Contents/Resources/"
rm -f "$app/Contents/MacOS/KlawosAgent"
codesign --force --sign "$identity" "$helper"
cp native/.build/out/Products/Debug/KlawosProbe "$app/Contents/Resources/"
rsync -a --delete --exclude='__pycache__' ui/ "$app/Contents/Resources/ui/"
rsync -a --delete --exclude='__pycache__' --exclude='tests' service/ "$app/Contents/Resources/service/"
rsync -a --delete --exclude='__pycache__' runtime/python/ "$app/Contents/Resources/python/"
cp THIRD-PARTY.md "$app/Contents/Resources/"
# Keep the certificate identity for both bundles across every update.
codesign --force --deep --sign "$identity" "$app"
codesign --verify --deep --strict "$app"
if [[ "$identity" != - ]]; then runtime/python/bin/python3.12 scripts/app_update.py --check "$app"; fi
printf '%s\n' "$resolved"
