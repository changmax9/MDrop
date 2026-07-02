#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MDrop"
BUNDLE_ID="com.maxchang.MDrop"
CONFIGURATION="${MDROP_CONFIGURATION:-Debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DERIVED_DATA="$ROOT_DIR/DerivedData"
BUILD_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

stage_swiftpm_bundle() {
  local developer_root="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  local toolchain="$developer_root/Toolchains/XcodeDefault.xctoolchain/usr/bin"
  local swift="$toolchain/swift"
  local swift_configuration
  swift_configuration="$(printf '%s' "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"

  if [[ ! -x "$swift" ]]; then
    echo "Swift toolchain not found at $swift" >&2
    exit 1
  fi

  export DEVELOPER_DIR="$developer_root"
  export SDKROOT="$developer_root/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
  export PATH="$toolchain:$PATH"

  "$swift" build \
    --package-path "$ROOT_DIR" \
    --configuration "$swift_configuration" \
    --product "$APP_NAME"

  local swift_bin_dir
  swift_bin_dir="$(
    "$swift" build \
      --package-path "$ROOT_DIR" \
      --configuration "$swift_configuration" \
      --show-bin-path
  )"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
  cp "$ROOT_DIR/Config/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
  cp "$swift_bin_dir/$APP_NAME" "$APP_BINARY"
  plutil -replace CFBundleExecutable -string "$APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleName -string "$APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "0.1.0" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "1" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace LSMinimumSystemVersion -string "26.0" "$APP_BUNDLE/Contents/Info.plist"

  local xcstringstool="$developer_root/usr/bin/xcstringstool"
  if [[ -x "$xcstringstool" ]]; then
    "$xcstringstool" compile \
      "$ROOT_DIR/Resources/Localizable.xcstrings" \
      --output-directory "$APP_BUNDLE/Contents/Resources"
  fi
  cp "$ROOT_DIR/Resources/AppIcon.icns" \
    "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
  cp "$ROOT_DIR/Resources/MDropMenuBarTemplate.pdf" \
    "$APP_BUNDLE/Contents/Resources/MDropMenuBarTemplate.pdf"
}

mkdir -p "$DIST_DIR"
if xcodebuild -license check >/dev/null 2>&1; then
  xcodebuild \
    -project "$ROOT_DIR/MDrop.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build

  rm -rf "$APP_BUNDLE"
  cp -R "$BUILD_APP" "$APP_BUNDLE"
else
  echo "Xcode license is pending; building the app bundle with the bundled Swift toolchain."
  stage_swiftpm_bundle
fi

find "$APP_BUNDLE/Contents" -type d -name '*.framework' -print0 |
  while IFS= read -r -d '' framework; do
    codesign --force --sign - "$framework"
  done
codesign \
  --force \
  --sign - \
  --requirements "$ROOT_DIR/Config/MDrop.requirements" \
  "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$BUILD_APP" >/dev/null 2>&1 || true
"$LSREGISTER" -f "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build-only|build-only)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
