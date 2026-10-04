#!/bin/bash
# Builds dist/LogiJuice.app (app + widget + CLI). Ad-hoc signed unless SIGNING_IDENTITY is set.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION="${LOGIJUICE_VERSION:-0.1.0}"
BUILD_NUMBER="${LOGIJUICE_BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
ARCH_FLAGS=(--arch arm64 --arch x86_64)
# Shortcuts actions only run in an app with a Team ID, so they're built only into signed apps.
# LOGIJUICE_APP_INTENTS=1 forces them on (to exercise the metadata step in an unsigned build).
if [[ "$SIGNING_IDENTITY" != "-" ]]; then APP_INTENTS="${LOGIJUICE_APP_INTENTS:-1}"; else APP_INTENTS="${LOGIJUICE_APP_INTENTS:-0}"; fi
APP_FLAGS=()
[[ "$APP_INTENTS" == 1 ]] && APP_FLAGS=(-Xswiftc -DLOGIJUICE_APP_INTENTS)
APP="$ROOT/dist/LogiJuice.app"

sign() {
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - --timestamp=none "$@"
  else
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$@"
  fi
}

swift build -c release "${ARCH_FLAGS[@]}" ${APP_FLAGS[@]+"${APP_FLAGS[@]}"} --product LogiJuice
swift build -c release "${ARCH_FLAGS[@]}" --product logijuice-cli
HAS_WIDGET=0
if [[ -d WidgetExtension ]]; then
  HAS_WIDGET=1
  swift build -c release "${ARCH_FLAGS[@]}" --product LogiJuiceWidgetExtension
fi
BIN="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

# App Intents metadata (Shortcuts actions). Xcode does this automatically; with SwiftPM the App target's
# release flags emit .build/LogiJuice.swiftconstvalues and this compiles it into Metadata.appintents.
AI="$ROOT/.build/appintents"
rm -rf "$AI" && mkdir -p "$AI/out"
if [[ "$APP_INTENTS" == 1 ]]; then
  ls "$ROOT"/App/*.swift > "$AI/sources.txt"
  echo "$ROOT/.build/LogiJuice.swiftconstvalues" > "$AI/constvals.txt"
  xcrun appintentsmetadataprocessor --output "$AI/out" \
    --toolchain-dir "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain" --module-name LogiJuice \
    --sdk-root "$(xcrun --sdk macosx --show-sdk-path)" \
    --xcode-version "$(xcodebuild -version | awk '/Build version/{print $3}')" \
    --platform-family macOS --deployment-target 14.0 --target-triple arm64-apple-macos14.0 \
    --source-file-list "$AI/sources.txt" --swift-const-vals-list "$AI/constvals.txt" --force >/dev/null
  if ! grep -q GetLowestBatteryIntent "$AI/out/Metadata.appintents/extract.actionsdata" 2>/dev/null; then
    printf 'App Intents metadata missing or empty; Shortcuts actions would not appear.\n' >&2
    exit 67
  fi
elif nm "$BIN/LogiJuice" > "$AI/symbols.txt" && grep -q GetLowestBatteryIntent "$AI/symbols.txt"; then
  printf 'Unsigned build contains the Shortcuts actions, which macOS would refuse to run; refusing to package.\n' >&2
  exit 68
fi

# An app extension must enter through _NSExtensionMain (Xcode links with `-e _NSExtensionMain`).
# Entering at WidgetBundle.main() directly leaves ExtensionFoundation uninitialised and the
# extension traps at launch, so the widget never appears in the gallery (diagnosed 2026-10-03).
if [[ "$HAS_WIDGET" == 1 ]] && ! nm -u "$BIN/LogiJuiceWidgetExtension" | grep -q '_NSExtensionMain$'; then
  printf 'Widget extension does not enter via _NSExtensionMain; refusing to package.\n' >&2
  exit 66
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
cp "$BIN/LogiJuice" "$APP/Contents/MacOS/LogiJuice"
cp "$BIN/logijuice-cli" "$APP/Contents/Resources/bin/logijuice"
chmod 0755 "$APP/Contents/Resources/bin/logijuice"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
[[ "$APP_INTENTS" == 1 ]] && cp -R "$AI/out/Metadata.appintents" "$APP/Contents/Resources/Metadata.appintents"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LogiJuice</string>
<key>CFBundleIdentifier</key><string>com.penguinspecz.logijuice</string>
<key>CFBundleName</key><string>LogiJuice</string>
<key>CFBundleDisplayName</key><string>LogiJuice</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>CFBundleURLTypes</key><array><dict>
  <key>CFBundleURLName</key><string>com.penguinspecz.logijuice</string>
  <key>CFBundleURLSchemes</key><array><string>logijuice</string></array>
</dict></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

if [[ "$HAS_WIDGET" == 1 ]]; then
  APPEX="$APP/Contents/PlugIns/LogiJuiceWidgetExtension.appex"
  mkdir -p "$APPEX/Contents/MacOS"
  cp "$BIN/LogiJuiceWidgetExtension" "$APPEX/Contents/MacOS/LogiJuiceWidgetExtension"
  cp WidgetExtension/Info.plist "$APPEX/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APPEX/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APPEX/Contents/Info.plist"
  plutil -lint "$APPEX/Contents/Info.plist"
  sign --entitlements Config/LogiJuiceWidget.entitlements "$APPEX"
fi

plutil -lint "$APP/Contents/Info.plist"
sign "$APP/Contents/Resources/bin/logijuice"
sign --entitlements Config/LogiJuice.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
