#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
staging="$(mktemp -d "${TMPDIR:-/tmp}/klawos-build.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
scripts/build-app.sh "$staging/KLAWOS Studio.app"
scripts/verify-package.sh "$staging/KLAWOS Studio.app"
runtime/python/bin/python3.12 scripts/app_update.py "$staging/KLAWOS Studio.app"
