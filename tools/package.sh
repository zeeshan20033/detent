#!/bin/bash
# Builds the zip attached to GitHub releases: a universal app that runs on Apple
# Silicon and Intel. Writes to dist/ and does not touch /Applications.
#
# Unlike build.sh this keeps the default ad-hoc signature, whose designated
# requirement is the binary's cdhash. Someone installing a release never
# rebuilds it, so there is no reason to loosen that check on their Mac.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" Info.plist)"
APP="dist/Detent.app"
ZIP="dist/Detent-$VERSION.zip"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for ARCH in arm64 x86_64; do
	echo "==> Compiling $ARCH"
	swiftc \
		-swift-version 5 \
		-O \
		-target "$ARCH-apple-macos14.0" \
		-framework AppKit \
		-framework AVFoundation \
		-framework ServiceManagement \
		-framework SwiftUI \
		-framework ApplicationServices \
		Sources/*.swift \
		-o "dist/Detent-$ARCH"
done

echo "==> Assembling bundle"
lipo -create dist/Detent-arm64 dist/Detent-x86_64 -output "$APP/Contents/MacOS/Detent"
rm dist/Detent-arm64 dist/Detent-x86_64
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/sounds "$APP/Contents/Resources/sounds"

echo "==> Signing (ad-hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

echo "==> Zipping"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Packaged $ZIP"
