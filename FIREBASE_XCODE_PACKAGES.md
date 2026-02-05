# Firebase Packages for Xcode (iOS)

## For Firebase App Distribution Only

**You don't need to add any packages!** Firebase App Distribution is just a distribution service - it doesn't require any Firebase SDK in your app code. You only need:

1. ✅ `GoogleService-Info.plist` file (already downloaded)
2. ✅ Firebase CLI for distribution (already installed)

That's it! You can skip the rest of this guide.

---

## If You Want Other Firebase Features

If you plan to use Firebase Analytics, Crashlytics, or other Firebase services in your app code, then you'll need to add Firebase packages.

### Option 1: Via Swift Package Manager (Recommended)

1. **Open Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Add Firebase Package:**
   - In Xcode: **File → Add Package Dependencies...**
   - Enter URL: `https://github.com/firebase/firebase-ios-sdk`
   - Click **"Add Package"**
   - Select version: **"Up to Next Major Version"** with `11.0.0` or latest

3. **Select Products to Add:**
   
   For **Firebase App Distribution** (distribution only - no packages needed):
   - ❌ None needed
   
   For **Firebase Analytics** (track events):
   - ✅ `FirebaseAnalytics`
   
   For **Firebase Crashlytics** (crash reporting):
   - ✅ `FirebaseCrashlytics`
   
   For **Firebase Remote Config** (feature flags):
   - ✅ `FirebaseRemoteConfig`
   
   For **Firebase Auth** (authentication - but you're using Supabase):
   - ❌ Skip (you're using Supabase for auth)
   
   For **Firebase Cloud Messaging** (push notifications):
   - ✅ `FirebaseMessaging`

4. **Add to Target:**
   - Select **"Runner"** target
   - Click **"Add Package"**

### Option 2: Via CocoaPods (Alternative)

If you prefer CocoaPods, add to `ios/Podfile`:

```ruby
target 'Runner' do
  use_frameworks!
  
  # Add Firebase pods if needed
  # pod 'Firebase/Analytics'
  # pod 'Firebase/Crashlytics'
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

Then run:
```bash
cd ios
pod install
```

---

## Recommended Packages (If Using Firebase Features)

### Minimal Setup (Analytics + Crashlytics):
- ✅ `FirebaseAnalytics`
- ✅ `FirebaseCrashlytics`

### Full Setup (All Features):
- ✅ `FirebaseAnalytics`
- ✅ `FirebaseCrashlytics`
- ✅ `FirebaseRemoteConfig`
- ✅ `FirebaseMessaging` (if using push notifications)

---

## For Your Travel App

Since you're using **Supabase for backend** and **Firebase App Distribution for beta testing**, you likely don't need any Firebase packages in Xcode.

**You only need:**
- ✅ `GoogleService-Info.plist` (for App Distribution)
- ✅ Firebase CLI (for distribution commands)

**Skip adding packages unless you want:**
- Firebase Analytics (event tracking)
- Firebase Crashlytics (crash reports)
- Other Firebase services

---

## Summary

**For App Distribution:** No packages needed ✅

**For other Firebase features:** Add packages via Swift Package Manager in Xcode
