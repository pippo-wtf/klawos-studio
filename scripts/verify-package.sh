#!/bin/bash
set -euo pipefail
app="${1:-dist/KLAWOS Studio.app}"
for file in Contents/Info.plist Contents/MacOS/KlawosStudio Contents/MacOS/KlawosAgent Contents/Resources/KlawosProbe Contents/Resources/python/bin/python3.12 Contents/Resources/service/klawos_device/app_service.py Contents/Resources/ui/index.html Contents/Resources/ui/models/klawos.glb Contents/Resources/ui/vendor/three/LICENSE Contents/Resources/service/klawos_device/vial/LICENSE Contents/Library/LaunchAgents/com.pippo.klawos.agent.plist; do
  test -f "$app/$file" || { printf 'Missing package component: %s\n' "$file"; exit 1; }
done
codesign --verify --deep --strict "$app"
"$app/Contents/Resources/python/bin/python3.12" -I -B -c 'import sys,ssl,lzma; assert sys.version_info[:2] == (3,12); print("Bundled Python:",sys.version.split()[0])'
PYTHONPATH="$app/Contents/Resources/service" PYTHONDONTWRITEBYTECODE=1 "$app/Contents/Resources/python/bin/python3.12" -c 'from klawos_device.app_service import handle; print("Bundled device service imports successfully")'
/usr/bin/file "$app/Contents/MacOS/KlawosStudio" "$app/Contents/MacOS/KlawosAgent" "$app/Contents/Resources/python/bin/python3.12"
printf '%s\n' 'Package structure and local ad-hoc signature verified. This does not establish notarization or physical acceptance.'
