#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.1.0}"
APP_PATH="$ROOT_DIR/dist/Sky.app"
DMG_PATH="$ROOT_DIR/dist/Sky-${VERSION}.dmg"

if [[ ! -d "$APP_PATH" ]]; then
    bash "$ROOT_DIR/scripts/build-app.sh"
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_PATH" "$STAGING/Sky.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
echo "==> Creating DMG at $DMG_PATH..."
hdiutil create \
    -volname "Sky ${VERSION}" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "==> Built DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
