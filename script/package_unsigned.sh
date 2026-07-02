#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MDrop"
VERSION="0.2.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/release"
STAGING_DIR="$DIST_DIR/dmg-root"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-arm64.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

rm -rf "$DIST_DIR"
mkdir -p "$STAGING_DIR"

MDROP_CONFIGURATION=Release \
  "$ROOT_DIR/script/build_and_run.sh" --build-only
cp -R "$ROOT_DIR/dist/$APP_NAME.app" "$APP_BUNDLE"

cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
cp "$ROOT_DIR/Distribution/README.txt" "$STAGING_DIR/README.txt"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"
rm -rf "$STAGING_DIR"

printf '%s\n%s\n%s\n' "$APP_BUNDLE" "$DMG_PATH" "$CHECKSUM_PATH"
