# Maps & Places API Setup

## Static Maps (Feed Card Thumbnails) – Free Option

For static map images on feed cards, you can use **Geoapify** (free tier: 3,000 credits/day) instead of Google:

1. Sign up at [Geoapify](https://www.geoapify.com/) and get an API key
2. Add to `.env`:
   ```
   GEOAPIFY_API_KEY=your-geoapify-key
   ```

When `GEOAPIFY_API_KEY` is set, the app uses:
- **Geoapify Static Maps** for map images
- **Nominatim** (OpenStreetMap) for geocoding – free, no API key, 1 request/second limit

If `GEOAPIFY_API_KEY` is not set, the app falls back to Google Maps Static API and Geocoding API (requires `GOOGLE_API_KEY` and billing).

---

## Google Maps & Places API (Map Display & Autocomplete)

This app uses **one API key** for map display and Places autocomplete. You do **not** need multiple keys for different features or device types.

### Fix Grey Map & Places Autocomplete

### 1. Go to Google Cloud Console

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)

### 2. Enable Required APIs

Go to **APIs & Services → Library** and enable:

- **Maps SDK for Android**
- **Maps SDK for iOS**
- **Maps JavaScript API** (required for web – itinerary map & visited countries map)
- **Places API**
- **Places API (New)**
- **Maps Static API** (for feed card map thumbnails – only if not using Geoapify)
- **Geocoding API** (for showing destination on map – only if not using Geoapify)

### 3. Enable Billing

Google Maps Platform requires billing to be enabled. Go to **Billing** and link a payment method. You get $200/month free credit.

### 4. Fix API Key Restrictions

Go to **APIs & Services → Credentials** → click your API key.

**Application restrictions:**
- Set to **None** (recommended for development)
- This allows the same key to work for:
  - Maps SDK (iOS & Android) – map display
  - Places API – town/venue autocomplete (called via HTTP from Flutter)

**Why "None"?** The Places autocomplete uses HTTP requests that don't send your app's bundle ID. If you restrict to "iOS apps", those requests are blocked. One unrestricted key works for everything.

**API restrictions:**
- Choose "Restrict key"
- Enable: Maps SDK for Android, Maps SDK for iOS, Maps JavaScript API, Places API, Places API (New), Maps Static API, Geocoding API

**For web deployment:** If restricting by HTTP referrer, add your deployed domains (e.g. `https://*.vercel.app/*`, `https://your-app.vercel.app/*`).

### 5. Add Your Key (Secure – keys are gitignored)

**Never commit API keys to git.** Add your key to these gitignored files:

**Android** – add to `android/local.properties`:
```
GOOGLE_MAPS_API_KEY=your-key-here
```

**iOS** – copy the example and add your key:
```bash
cp ios/Flutter/GoogleMapsKeys.xcconfig.example ios/Flutter/GoogleMapsKeys.xcconfig
# Edit GoogleMapsKeys.xcconfig and replace YOUR_GOOGLE_MAPS_API_KEY_HERE with your key
```

**Flutter (Places API)** – add to `.env`:
```
GOOGLE_API_KEY=your-key-here
```

### 6. Rebuild

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

Wait 2–5 minutes after changing API key restrictions for changes to propagate.

---

## Still Grey? Try This

### Create a Brand New API Key

Sometimes keys get into a bad state. Create a fresh one:

1. **APIs & Services → Credentials**
2. Click **+ CREATE CREDENTIALS** → **API key**
3. Copy the new key immediately
4. Click **Restrict key** (or edit the key):
   - **Application restrictions:** None
   - **API restrictions:** Restrict key → enable Maps SDK for Android, Maps SDK for iOS, Maps JavaScript API, Places API, Places API (New), Maps Static API, Geocoding API
5. **Save**
6. Update the key in all three places (see step 5 above)
7. **Wait 5–10 minutes** for propagation
8. Full rebuild (see below)

### Verify APIs Are Enabled

Go to **APIs & Services → Enabled APIs**. You must see:

- Maps SDK for Android
- Maps SDK for iOS
- Maps JavaScript API
- Places API
- Places API (New)
- Maps Static API
- Geocoding API

If any are missing, enable them from the Library.

### Verify Billing Is Linked to This Project

1. **Billing** → **Account management**
2. Select your billing account
3. Under **My projects**, your project should show **Linked** (not "No billing")

### Full Clean Rebuild

```bash
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf build
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter run
```

### Test on a Physical Device

The iOS Simulator can sometimes behave differently. Try running on a real iPhone if you have one.

### Check the Console

When you run the app, look for `[GoogleMaps] API key configured:` in the Xcode/Flutter console. This confirms the key is being loaded. If you see a different key than expected, the wrong key is in your config.
