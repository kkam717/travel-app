#!/bin/bash
# Build and distribute beta builds via Firebase App Distribution
set -e

cd "$(dirname "$0")/.."

PLATFORM=${1:-android}

if [ "$PLATFORM" != "android" ] && [ "$PLATFORM" != "ios" ]; then
  echo "Usage: $0 [android|ios]"
  echo "Example: $0 android"
  exit 1
fi

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | sed 's/+.*//' | tr -d '\r')

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
  echo "❌ Firebase CLI not found. Install it with:"
  echo "   curl -sL https://firebase.tools | bash"
  echo "   or: npm install -g firebase-tools"
  exit 1
fi

# Check if logged in
if ! firebase projects:list &> /dev/null; then
  echo "❌ Not logged in to Firebase. Run: firebase login"
  exit 1
fi

# Get release notes (optional)
RELEASE_NOTES=${2:-"Beta build v${VERSION} - $(date +%Y-%m-%d)"}

if [ "$PLATFORM" == "android" ]; then
  echo "📱 Building Android APK..."
  flutter build apk --release
  
  APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
  
  if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found at $APK_PATH"
    exit 1
  fi
  
  echo ""
  echo "📤 Distributing to Firebase App Distribution..."
  echo "   Release notes: $RELEASE_NOTES"
  echo ""
  
  # Check if ANDROID_APP_ID is set in environment or .env
  if [ -z "$ANDROID_APP_ID" ]; then
    if [ -f .env ]; then
      ANDROID_APP_ID=$(grep "^ANDROID_APP_ID=" .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    fi
  fi
  
  if [ -z "$ANDROID_APP_ID" ]; then
    echo "⚠️  ANDROID_APP_ID not set."
    echo ""
    echo "To find your Android App ID:"
    echo "1. Go to Firebase Console → Project Settings → Your apps → Android app"
    echo "2. Copy the App ID (looks like: 1:123456789:android:abc123def456)"
    echo ""
    echo "Set it in one of these ways:"
    echo "  export ANDROID_APP_ID='your-app-id'"
    echo "  or add to .env: ANDROID_APP_ID='your-app-id'"
    echo ""
    read -p "Enter your Android App ID: " ANDROID_APP_ID
  fi
  
  firebase appdistribution:distribute "$APK_PATH" \
    --app "$ANDROID_APP_ID" \
    --groups "beta-testers" \
    --release-notes "$RELEASE_NOTES"
  
  echo ""
  echo "✅ Android build distributed!"
  echo "   Testers will receive an email invite."
  
elif [ "$PLATFORM" == "ios" ]; then
  echo "📱 Building iOS IPA (Ad Hoc for Firebase App Distribution)..."
  flutter build ipa --export-method ad-hoc
  
  IPA_PATH=$(find build/ios/ipa -name "*.ipa" | head -1)
  
  if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA not found. Check build/ios/ipa/"
    exit 1
  fi
  
  echo ""
  echo "📤 Distributing to Firebase App Distribution..."
  echo "   Release notes: $RELEASE_NOTES"
  echo ""
  
  # Check if IOS_APP_ID is set in environment or .env
  if [ -z "$IOS_APP_ID" ]; then
    if [ -f .env ]; then
      IOS_APP_ID=$(grep "^IOS_APP_ID=" .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    fi
  fi
  
  if [ -z "$IOS_APP_ID" ]; then
    echo "⚠️  IOS_APP_ID not set."
    echo ""
    echo "To find your iOS App ID:"
    echo "1. Go to Firebase Console → Project Settings → Your apps → iOS app"
    echo "2. Copy the App ID (looks like: 1:123456789:ios:abc123def456)"
    echo ""
    echo "Set it in one of these ways:"
    echo "  export IOS_APP_ID='your-app-id'"
    echo "  or add to .env: IOS_APP_ID='your-app-id'"
    echo ""
    read -p "Enter your iOS App ID: " IOS_APP_ID
  fi
  
  firebase appdistribution:distribute "$IPA_PATH" \
    --app "$IOS_APP_ID" \
    --groups "beta-testers" \
    --release-notes "$RELEASE_NOTES"
  
  echo ""
  echo "✅ iOS build distributed!"
  echo "   Testers will receive an email invite."
fi

echo ""
echo "📧 Check Firebase Console → App Distribution to see the distribution status."
