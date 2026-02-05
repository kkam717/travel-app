# Travel App

<!-- Updated via agent test -->

A Flutter mobile application for travel planning and itinerary sharing. Built for **iOS** and **Android**.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.5.0 or higher)
- [Supabase](https://supabase.com) account
- **iOS**: Xcode, CocoaPods
- **Android**: Android Studio, Android SDK

## Environment Setup

1. Copy the example env file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your Supabase credentials:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

   Get these from your Supabase project: **Settings → API**

## Supabase Setup

1. Create a new project at [supabase.com](https://supabase.com)

2. Run the SQL migrations in order:
   - Go to **SQL Editor** in Supabase Dashboard
   - Run the contents of `supabase/migrations/001_initial_schema.sql`

3. Enable Email auth:
   - Go to **Authentication → Providers**
   - Enable Email provider
   - (Optional) Disable "Confirm email" for development

4. Configure Storage (for profile photos):
   - The migration creates an `avatars` bucket
   - Ensure Storage is enabled in your project

## Run the App

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run on iOS Simulator:
   ```bash
   open -a Simulator
   flutter run -d ios
   ```

3. Run on Android Emulator:
   ```bash
   flutter emulators --launch <emulator_id>
   flutter run -d android
   ```

4. Run on a physical device:
   ```bash
   flutter devices
   flutter run -d <device_id>
   ```

## Project Structure

```
lib/
├── core/           # Theme, analytics
├── data/           # Static data (countries, etc.)
├── models/         # Data models
├── screens/        # UI screens
├── services/       # Supabase service
├── main.dart
└── router.dart
supabase/
└── migrations/     # SQL migrations
```

## MVP Features (Phase 1)

- **Auth**: Email sign up/sign in via Supabase
- **Onboarding**: Countries visited, travel styles, travel mode
- **Main tabs**: Search, Create, Saved, Profile
- **Itineraries**: Create, search, detail, bookmark, fork
- **Profile**: Photo, visited countries, travel preferences, favourite trip
- **Places**: Internal autocomplete (≥3 chars) with custom entry

## Next Steps (Phase 2)

- **Feed**: Discover feed with friend-ranked itineraries
- **Friends**: Friend requests and friends graph
- **Social**: Share itineraries with friends, comments
- **Apple/Google Sign In**: OAuth providers
- **Map integration**: Show stops on map in itinerary detail
- **Google Places API**: Replace internal places with Places autocomplete
- **Analytics**: Firebase/Mixpanel integration (hooks are in place)

## Troubleshooting

- **Supabase connection fails**: Verify `.env` has correct URL and anon key
- **RLS errors**: Ensure migrations ran successfully; check RLS policies in Supabase
- **iOS build fails**: Run `cd ios && pod install && cd ..`
- **Android build fails**: Run `flutter clean && flutter pub get`
