#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MiniBuddy AI"
EXEC="MiniBuddyAI"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
DMG="$BUILD_DIR/$APP_NAME.dmg"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift not found. Install Xcode first:"
  echo "xcode-select --install"
  exit 1
fi

echo "==> 1/5 Compiling release build"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/$EXEC"

if [ ! -f "$BIN" ]; then
  echo "Build did not produce binary: $BIN"
  exit 1
fi

echo "==> 2/5 Build app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXEC"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MiniBuddyAI</string>
    <key>CFBundleIdentifier</key>
    <string>com.minibuddyai.app</string>
    <key>CFBundleName</key>
    <string>MiniBuddy AI</string>
    <key>CFBundleDisplayName</key>
    <string>MiniBuddy AI</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> 3/5 Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> 4/5 Creating DMG"
STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "==> 5/5 Verifying DMG"
hdiutil verify "$DMG"

MOUNT="$(hdiutil attach "$DMG" -nobrowse -readonly | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)"

if [ -d "$MOUNT/$APP_NAME.app" ] && [ -L "$MOUNT/Applications" ]; then
  echo "DMG is valid"
  STATUS=0
else
  echo "DMG validation failed"
  STATUS=1
fi

hdiutil detach "$MOUNT" -quiet || true
[ "$STATUS" -eq 0 ] || exit 1

echo
echo "Done: $DMG"
open -R "$DMG" || true
