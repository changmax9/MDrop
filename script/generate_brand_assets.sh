#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASTER="$ROOT_DIR/Resources/Brand/MDropMark.svg"
MENU_MASTER="$ROOT_DIR/Resources/Brand/MDropMenuBarTemplate.svg"
ICON_OUTPUT="$ROOT_DIR/Resources/AppIcon.icns"
MENU_OUTPUT="$ROOT_DIR/Resources/MDropMenuBarTemplate.png"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mdrop-brand.XXXXXX")"
ICONSET="$WORK_DIR/AppIcon.iconset"
BASE_PNG="$WORK_DIR/AppIcon-1024.png"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$ICONSET"
sips -s format png "$MASTER" --out "$BASE_PNG" >/dev/null

render_icon() {
  local points="$1"
  local scale="$2"
  local pixels=$((points * scale))
  local suffix=""
  if [[ "$scale" -eq 2 ]]; then
    suffix="@2x"
  fi
  sips \
    --resampleHeightWidth "$pixels" "$pixels" \
    "$BASE_PNG" \
    --out "$ICONSET/icon_${points}x${points}${suffix}.png" \
    >/dev/null
}

render_icon 16 1
render_icon 16 2
render_icon 32 1
render_icon 32 2
render_icon 128 1
render_icon 128 2
render_icon 256 1
render_icon 256 2
render_icon 512 1
render_icon 512 2

iconutil -c icns "$ICONSET" -o "$ICON_OUTPUT"
sips \
  -s format png \
  --resampleHeightWidth 36 36 \
  "$MENU_MASTER" \
  --out "$MENU_OUTPUT" \
  >/dev/null

printf '%s\n%s\n' "$ICON_OUTPUT" "$MENU_OUTPUT"
