#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SIGN_ID="${SIGN_ID:--}"
APP="build/Bokich.app"
ICON="Resources/AppIcon.icns"
if [ ! -f "$ICON" ] || [ Tools/MakeIcon.swift -nt "$ICON" ]; then
  mkdir -p Resources build
  rm -rf build/AppIcon.iconset
  swift Tools/MakeIcon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o "$ICON"
fi
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Bokich "$APP/Contents/MacOS/Bokich"
cp Info.plist "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign "$SIGN_ID" "$APP"
echo "Built $APP"
