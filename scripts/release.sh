#!/bin/bash
# Builds the release zip: tests, then scripts/build-app.sh, then dist/LogiJuice-<version>.zip and its SHA-256.
# Publishes nothing. Releases are ad-hoc signed until the owner settles who signs (see docs/status/LAWS.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export LOGIJUICE_VERSION="${LOGIJUICE_VERSION:-0.1.0}"
ZIP="$ROOT/dist/LogiJuice-$LOGIJUICE_VERSION.zip"

swift test
scripts/build-app.sh

codesign --verify --deep --strict dist/LogiJuice.app
rm -f "$ZIP"
# ditto keeps the bundle's symlinks, extended attributes and signature intact (plain zip doesn't).
ditto -c -k --keepParent dist/LogiJuice.app "$ZIP"

SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo
echo "Built $ZIP"
echo "sha256 $SHA"
echo "To publish: attach the zip to GitHub release v$LOGIJUICE_VERSION, then set sha256 \"$SHA\" in Casks/logijuice.rb."
