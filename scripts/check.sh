#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
PYTHONPATH=service runtime/python/bin/python3.12 -m unittest discover -s service/tests -v
swift test --package-path native
node --test tests/ui/*.test.mjs
for file in ui/*.js ui/*.mjs; do node --check "$file"; done
