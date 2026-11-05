#!/bin/zsh
# Builds build/FanTemp.app with the Xcode Command Line Tools; no Xcode project needed.
set -euo pipefail
cd "${0:A:h}"

app=build/FanTemp.app
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/"
swiftc -O -sdk "$(xcrun --show-sdk-path)" -module-cache-path build/module-cache \
    -import-objc-header Sources/Bridge.h Sources/*.swift \
    -o "$app/Contents/MacOS/FanTemp"
codesign --force --sign - "$app"
echo "Built $PWD/$app"
