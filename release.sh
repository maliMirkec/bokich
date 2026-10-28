#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export SIGN_ID="${SIGN_ID:-Bokich Dev}"
APP="build/Bokich.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
ZIP="dist/Bokich-$VERSION.zip"
rm -f Resources/AppIcon.icns
./build.sh
codesign --verify --deep --strict "$APP"
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Version: $VERSION"
echo "Zip: $ZIP"
shasum -a 256 "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d " " -f 1)
sed -e "s/VERSION/$VERSION/" -e "s/SHA256/$SHA/" packaging/bokich.rb > dist/bokich.rb
echo "Cask: dist/bokich.rb"
