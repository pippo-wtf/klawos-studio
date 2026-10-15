#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build --package-path native
app="${1:-dist/KLAWOS Studio.app}"
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
codesign --force --sign - "$helper"
cp native/.build/out/Products/Debug/KlawosProbe "$app/Contents/Resources/"
rsync -a --delete --exclude='__pycache__' ui/ "$app/Contents/Resources/ui/"
rsync -a --delete --exclude='__pycache__' --exclude='tests' service/ "$app/Contents/Resources/service/"
rsync -a --delete --exclude='__pycache__' runtime/python/ "$app/Contents/Resources/python/"
cp THIRD-PARTY.md "$app/Contents/Resources/"
# Development identity only. Distribution signing/notarization is a separate release gate.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
printf '%s\n' "$PWD/$app"
