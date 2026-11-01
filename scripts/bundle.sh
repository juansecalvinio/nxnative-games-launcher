#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

app=build/GamesLauncher.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/GamesLauncher" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
echo "$app"
