# Firebase App Distribution Setup Guide

This guide walks you through setting up Firebase App Distribution for your Travel App to easily share beta builds with testers.

## Prerequisites

- A Google account
- Flutter SDK installed
- Android Studio / Xcode (for building)
- Firebase CLI installed (we'll do this in Step 2)

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `Travel App` (or your preferred name)
4. **Disable Google Analytics** (optional - you can enable later if needed)
5. Click **"Create project"**
6. Wait for project creation, then click **"Continue"**

---

## Step 2: Install Firebase CLI

### macOS/Linux:
```bash
curl -sL https://firebase.tools | bash
```

### Windows:
```bash
npm install -g firebase-tools
```

### Verify installation:
```bash
firebase --version
```

### Login to Firebase:
```bash
firebase login
```
This opens your browser - sign in with your Google account.

---

## Step 3: Add Your App to Firebase

### For Android:

1. In Firebase Console, click the **Android icon** (or "Add app")
2. **Android package name**: Check your `android/app/build.gradle.kts` for `applicationId`
   - Usually something like `com.example.travel_app`
3. **App nickname** (optional): `Travel App Android`
4. **Debug signing certificate SHA-1** (optional for App Distribution - skip for now)
5. Click **"Register app"**
6. Download `google-services.json`
7. Place it in: `android/app/google-services.json`

### For iOS:

1. In Firebase Console, click the **iOS icon** (or "Add app")
2. **iOS bundle ID**: Check your `ios/Runner.xcodeproj` or `ios/Runner/Info.plist`
   - Usually something like `com.example.travelApp`
3. **App nickname** (optional): `Travel App iOS`
4. **App Store ID** (optional - skip for now)
5. Click **"Register app"**
6. Download `GoogleService-Info.plist`
7. Place it in: `ios/Runner/GoogleService-Info.plist`

---

## Step 4: Initialize Firebase in Your Project

Run in your project root:
```bash
firebase init
```

Select:
- ✅ **App Distribution** (use arrow keys and spacebar to select)
- Press Enter

Choose:
- **Existing project** → Select your "Travel App" project
- **App Distribution token file path**: Press Enter (default is fine)
- **App Distribution groups**: Press Enter (we'll create groups in console)

---

## Step 5: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Add to your PATH (if not already):
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

---

## Step 6: Configure Flutter App for Firebase

Run:
```bash
flutterfire configure
```

This will:
- Detect your Firebase projects
- Let you select the project you created
- Configure both Android and iOS automatically
- Update necessary files

**Note**: If you already placed `google-services.json` and `GoogleService-Info.plist` manually, this step will overwrite them (which is fine).

---

## Step 7: Add Firebase App Distribution Plugin

Add to `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  integration_test:
    sdk: flutter
  mocktail: ^1.0.4
  firebase_app_distribution: ^0.5.0+1  # Add this line
```

Then run:
```bash
flutter pub get
```

---

## Step 8: Create Tester Groups (Optional but Recommended)

1. Go to Firebase Console → **App Distribution**
2. Click **"Testers & Groups"** tab
3. Click **"Create group"**
4. Name: `beta-testers` (or your preferred name)
5. Add tester emails (you can add more later)
6. Click **"Create"**

---

## Step 9: Build and Distribute

### For Android:

```bash
# Build the APK
flutter build apk --release

# Distribute via Firebase
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_ANDROID_APP_ID \
  --groups "beta-testers" \
  --release-notes "Latest changes from cloud agents"
```

**To find your Android App ID:**
- Firebase Console → Project Settings → Your apps → Android app
- Copy the **App ID** (looks like `1:123456789:android:abc123def456`)

### For iOS:

```bash
# Build the IPA
flutter build ipa

# Distribute via Firebase
firebase appdistribution:distribute build/ios/ipa/*.ipa \
  --app YOUR_IOS_APP_ID \
  --groups "beta-testers" \
  --release-notes "Latest changes from cloud agents"
```

**To find your iOS App ID:**
- Firebase Console → Project Settings → Your apps → iOS app
- Copy the **App ID**

---

## Step 10: Use the Distribution Script

We've created a script to make this easier. See `scripts/distribute_beta.sh`.

Run:
```bash
./scripts/distribute_beta.sh android
# or
./scripts/distribute_beta.sh ios
```

---

## Testing the Setup

1. Build and distribute a test build:
   ```bash
   flutter build apk --release
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
     --app YOUR_ANDROID_APP_ID \
     --groups "beta-testers"
   ```

2. Check your email - you should receive an invite
3. Click the link and install the app on your device
4. Test that it works!

---

## Troubleshooting

### "App not found" error
- Make sure you've added the app in Firebase Console
- Double-check the App ID matches exactly

### "Authentication failed"
- Run `firebase login` again
- Make sure you're using the correct Google account

### Build fails
- Make sure `google-services.json` is in `android/app/`
- Make sure `GoogleService-Info.plist` is in `ios/Runner/`
- Run `flutter clean && flutter pub get`

### iOS build requires signing
- Open `ios/Runner.xcworkspace` in Xcode
- Configure signing in Xcode (Team, certificates)
- Or use `flutter build ipa --release` which handles signing

---

## Next Steps

- Add more testers to your groups
- Set up automated distribution in CI/CD
- Add release notes automatically from git commits
- Integrate with your cloud agent workflow

---

## Quick Reference

**Find App IDs:**
- Firebase Console → Project Settings → Your apps

**Distribute Android:**
```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_ANDROID_APP_ID --groups "beta-testers"
```

**Distribute iOS:**
```bash
firebase appdistribution:distribute build/ios/ipa/*.ipa \
  --app YOUR_IOS_APP_ID --groups "beta-testers"
```
