# Shareable Beta – Travel App

This guide helps you build and share a beta version of the Travel App with friends.

---

## Web (Free for iOS & Android)

**Easiest way to share with iPhone users (no Apple Developer account):**

1. Build the web app: `./scripts/build_web.sh`
2. Deploy `build/web/` to [Netlify Drop](https://app.netlify.com/drop), Vercel, or any static host
3. Share the URL – friends open it in Safari/Chrome and can "Add to Home Screen" for an app-like experience

See **WEB_DEPLOYMENT.md** for details.

---

## Quick Start (Android)

**Fastest way to share with Android users:**

1. Build the APK:
   ```bash
   ./scripts/build_beta.sh
   ```
   Or manually:
   ```bash
   flutter build apk --release
   ```

2. Find the APK at:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

3. Share it:
   - **Google Drive / Dropbox**: Upload the APK, share the link
   - **Email**: Attach the APK (may be blocked by some providers)
   - **AirDrop** (Mac → iPhone/Android): Works for nearby devices

4. Tell your friends:
   - Download the APK
   - Enable **Install from unknown sources** (Settings → Security)
   - Open the APK and install

---

## iOS (TestFlight)

**For iPhone users, use Apple TestFlight:**

### Prerequisites
- Apple Developer account ($99/year)
- Mac with Xcode

### Steps

1. **Configure signing in Xcode**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select the Runner target → Signing & Capabilities
   - Choose your Team and enable "Automatically manage signing"

2. **Create an app in App Store Connect**
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - My Apps → + → New App
   - Fill in name, bundle ID (`com.example.travel_app`), SKU

3. **Build and upload**
   ```bash
   flutter build ipa
   ```
   Then upload the `.ipa` from `build/ios/ipa/` via Xcode → Window → Organizer → Distribute App, or use:
   ```bash
   xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u YOUR_APPLE_ID
   ```

4. **Add testers**
   - App Store Connect → Your App → TestFlight
   - Add internal testers (up to 100) or external testers (requires Beta App Review)
   - Invite friends by email

---

## Alternative: Firebase App Distribution

**Unified beta for both Android and iOS:**

1. Add Firebase to your project: [Firebase Console](https://console.firebase.google.com)
2. Add the `firebase_app_distribution` plugin to your Flutter project
3. Build and distribute:
   ```bash
   flutter build apk --release
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
     --app YOUR_FIREBASE_APP_ID --groups "beta-testers"
   ```
4. Invite testers via email; they get a link to install

---

## Before Sharing

- [ ] Ensure `.env` has production Supabase URL and keys (the app bundles these)
- [ ] Test sign-up and email verification flow
- [ ] Add `GOOGLE_MAPS_API_KEY` to `android/local.properties` for maps
- [ ] For iOS: Add Google Maps key to `ios/Runner/Info.plist` or `GoogleMapsKeys.xcconfig`

---

## Beta Message Template

Copy and send to friends:

```
Hey! I'm testing a travel planning app and would love your feedback.

Android: [Your download link]
iOS: [TestFlight invite link if using TestFlight]

Install, create an account, and try creating an itinerary. Let me know what you think!
```
