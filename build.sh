#!/bin/bash
# Builds Detent.app. No Xcode project required — just the command line tools.
set -euo pipefail

cd "$(dirname "$0")"

APP="build/Detent.app"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" Info.plist)"

echo "==> Regenerating click voices"
python3 tools/make_sounds.py >/dev/null

echo "==> Clearing previous build"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling"
swiftc \
	-swift-version 5 \
	-O \
	-target "$(uname -m)-apple-macos14.0" \
	-framework AppKit \
	-framework AVFoundation \
	-framework ServiceManagement \
	-framework SwiftUI \
	-framework ApplicationServices \
	Sources/*.swift \
	-o "$APP/Contents/MacOS/Detent"

echo "==> Assembling bundle"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/sounds "$APP/Contents/Resources/sounds"

# Ad-hoc, but with an explicit designated requirement. By default an ad-hoc
# signature's DR is the binary's cdhash, which changes on every build — macOS
# then treats each build as a different app and silently drops the Accessibility
# grant. Pinning the DR to the bundle identifier keeps it stable, so the
# permission is granted once and survives every rebuild.
echo "==> Signing"
codesign --force --sign - \
	--identifier "$BUNDLE_ID" \
	--requirements "=designated => identifier \"$BUNDLE_ID\"" \
	"$APP"

# Install to a stable path so the Accessibility entry always points at the same
# place. Only the signature changes between builds, never the location.
echo "==> Installing to /Applications"
pkill -f "Detent.app" 2>/dev/null || true
sleep 1
rm -rf "/Applications/Detent.app"
cp -R "$APP" "/Applications/Detent.app"

echo
echo "Installed /Applications/Detent.app"
echo "Run it with:  open -a Detent"
