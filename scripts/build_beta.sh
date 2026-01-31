#!/bin/bash
# Build a shareable beta APK for the Travel App
set -e

cd "$(dirname "$0")/.."
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | sed 's/+.*//' | tr -d '\r')
OUTPUT_DIR="beta"
APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_DEST="$OUTPUT_DIR/TravelApp-beta-v${VERSION}.apk"

echo "Building Travel App beta (v$VERSION)..."
flutter build apk --release

mkdir -p "$OUTPUT_DIR"
cp "$APK_SRC" "$APK_DEST"
echo ""
echo "✓ Beta APK ready: $APK_DEST"
echo ""
echo "Share this file with friends. They'll need to enable 'Install from unknown sources' to install."
echo "See BETA_DISTRIBUTION.md for iOS (TestFlight) and other options."
