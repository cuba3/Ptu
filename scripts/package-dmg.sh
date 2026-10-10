#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/PtuPackage"
DIST="$ROOT/dist"
APP="Ptu"
VERSION="1.0"
ARCHIVE="$WORK/$APP.xcarchive"
STAGE="$WORK/dmg"
DMG="$DIST/$APP-$VERSION.dmg"

rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

xcodebuild archive \
  -project "$ROOT/Ptu.xcodeproj" \
  -scheme "$APP" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  AD_HOC_CODE_SIGNING_ALLOWED=YES

APP_PATH="$ARCHIVE/Products/Applications/$APP.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Archived app not found at $APP_PATH" >&2
  exit 1
fi

# actool writes a partial AppIcon.icns; keep the full 16–1024 set.
cp "$ROOT/Ptu/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP_PATH"

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP_PATH" "$STAGE/$APP.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "Created $DMG"
