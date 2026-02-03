# Travel App — User Flow

This document describes the main user flows through the app, from first launch to common actions.

---

## 1. First-Time User: Sign Up → Onboarding → Home

```
Welcome Screen
    │
    ├─► Tap "Sign up"
    │       │
    │       └─► Email Auth Screen (sign-up mode)
    │               │
    │               ├─► Enter email, password
    │               ├─► Tap "Sign up"
    │               └─► [Success] → Redirect to Onboarding
    │
    └─► Tap "Sign in"
            │
            └─► Email Auth Screen (sign-in mode)
                    │
                    ├─► Enter email, password
                    ├─► Tap "Sign in"
                    └─► [Success] → Redirect to Onboarding (if new) or Home
```

**Onboarding (3 steps):**

```
Step 1: Your name
    │
    ├─► Enter name
    └─► Tap "Next"

Step 2: Countries visited
    │
    ├─► Search / select countries (checkboxes)
    └─► Tap "Next"

Step 3: Travel preferences
    │
    ├─► Select travel styles (e.g. adventure, foodie)
    ├─► Select mode (solo, couple, friends, family)
    └─► Tap "Finish"
            │
            └─► Redirect to Home
```

---

## 2. Returning User: Sign In → Home

```
Welcome Screen
    │
    └─► Tap "Sign in"
            │
            └─► Email Auth Screen
                    │
                    └─► [Success] → Home (onboarding already complete)
```

---

## 3. Main Shell Navigation

```
Home ◄──► Search ◄──► Saved ◄──► Profile
  │
  └─► FAB: Create new itinerary → Create Itinerary Screen
```

- **Home** — Feed of itineraries
- **Search** — Profiles and itineraries
- **Saved** — Bookmarked + Planning tabs
- **Profile** — Own profile
- **FAB** — Always visible; goes to Create Itinerary

---

## 4. Home Feed Flow

```
Home Screen
    │
    ├─► Tab: "For You" (merged feed + discover)
    │       │
    │       ├─► Scroll → Load more (infinite scroll)
    │       ├─► Pull to refresh → Reload feed
    │       │
    │       ├─► Tap itinerary card → Itinerary Detail Screen
    │       │
    │       ├─► Tap author name → Author Profile Screen
    │       │
    │       ├─► Tap like (thumbs up) → Toggle like (others' posts only)
    │       │
    │       ├─► Tap bookmark icon → Toggle bookmark
    │       │
    │       └─► Tap translate button → Translate content (if different language)
    │
    └─► Tab: "Following" (followed users only)
            │
            ├─► Scroll → Load more (infinite scroll)
            ├─► Pull to refresh → Reload feed
            │
            ├─► Tap itinerary card → Itinerary Detail Screen
            │
            ├─► Tap author name → Author Profile Screen
            │
            ├─► Tap like (thumbs up) → Toggle like (others' posts only)
            │
            ├─► Tap bookmark icon → Toggle bookmark
            │
            └─► Tap translate button → Translate content (if different language)
```

**State Sync:** When returning from Itinerary Detail, like and bookmark states sync automatically to home feed.

---

## 5. Create Itinerary Flow (7 Steps)

```
Create Itinerary Screen
    │
    ├─► Step 1: Start New Trip
    │       ├─► Enter title
    │       ├─► Select destination (Google Places)
    │       ├─► Select mode (budget/standard/luxury)
    │       ├─► Select visibility (public/private)
    │       └─► Tap "Next"
    │
    ├─► Step 2: Add Destinations
    │       ├─► Add cities/towns/volcanoes/deserts/mountains (Google Places)
    │       ├─► Country filtering (strict filtering by selected countries)
    │       ├─► Reorder (drag)
    │       ├─► Remove destinations
    │       └─► Tap "Next"
    │
    ├─► Step 3: Assign Days
    │       ├─► Assign each destination to a day
    │       └─► Tap "Next"
    │
    ├─► Step 4: Trip Map
    │       ├─► Preview route on map
    │       └─► Tap "Next"
    │
    ├─► Step 5: Add Details
    │       ├─► For each destination: add venues (eat, drink, hotel, guide)
    │       ├─► Google Places autocomplete per venue
    │       ├─► Add transport transitions (type + description) between destinations
    │       ├─► Reorder / remove venues
    │       └─► Tap "Next"
    │
    ├─► Step 6: Review Trip
    │       ├─► Review summary
    │       ├─► Tap step to edit (optional)
    │       └─► Tap "Next"
    │
    └─► Step 7: Save Trip
            ├─► Tap "Save"
            └─► [Success] → Itinerary Detail Screen (or back to previous screen)
```

**Edit flow:** Same 7 steps, pre-filled with existing data. Access via "Edit" on Itinerary Detail.

---

## 6. Itinerary Detail Flow

```
Itinerary Detail Screen
    │
    ├─► Tap author → Author Profile Screen
    │
    ├─► Tap like (thumbs up) → Toggle like (others' posts only)
    │       └─► Like count updates
    │
    ├─► Tap bookmark → Toggle bookmark
    │
    ├─► Tap spot on map → Open in Google Maps / Apple Maps
    │
    ├─► Tap translate button → Translate title/destination (if different language)
    │
    ├─► Tap share → Share itinerary link
    │
    ├─► Tap "Edit" (own itinerary) → Create Itinerary Screen (edit mode)
    │
    ├─► Tap "Use this trip" → Fork into Planning → Create Itinerary Screen (pre-filled)
    │
    └─► Tap back → Returns to previous screen with like/bookmark state synced
```

**State Sync:** When navigating back, like and bookmark states are passed back to home feed and updated automatically.

---

## 7. Saved Screen Flow

```
Saved Screen
    │
    ├─► Tab: Bookmarked
    │       ├─► Tap card → Itinerary Detail
    │       └─► Tap remove → Unbookmark
    │
    └─► Tab: Planning
            ├─► Tap card → Itinerary Detail (or edit)
            └─► Tap delete → Remove from planning
```

---

## 8. Search Flow

```
Search Screen
    │
    ├─► Tab: Profiles
    │       ├─► Type query → Search profiles (debounced 400ms)
    │       ├─► Tap profile → Author Profile Screen
    │       ├─► Tap follow/unfollow → Toggle follow
    │       └─► Recent searches shown when query empty
    │
    └─► Tab: Itineraries
            ├─► Type query → Search itineraries (debounced 400ms)
            ├─► Set filters (days, styles, mode)
            ├─► Search includes cities, volcanoes, deserts, mountains
            ├─► Country filtering (strict filtering)
            ├─► Tap card → Itinerary Detail
            ├─► Tap author → Author Profile Screen
            ├─► Tap like → Toggle like (others' posts only)
            ├─► Tap bookmark → Toggle bookmark
            └─► Recent searches shown when query empty
```

---

## 9. Profile Flow (Own)

```
Profile Screen
    │
    ├─► Tap avatar → Upload photo (gallery)
    │
    ├─► Tap current city (in card) → City Detail Screen
    │
    ├─► Tap "Countries" card → Visited Countries Map (editable)
    │       └─► Edit → Country picker → Save → Back to Profile
    │
    ├─► Tap "Trips" card → My Trips Screen (itineraries list)
    │
    ├─► Tap Followers/Following bar → Followers Screen
    │
    ├─► Tap past city chip → City Detail Screen
    │
    ├─► Tap edit (app bar) → Edit sheet (name, current city, past cities, travel styles)
    │
    ├─► Tap QR code (app bar) → Profile QR Screen
    │
    ├─► Tap settings (app bar) → Settings Screen
    │
    └─► Tap "Sign out" (Settings) → Welcome Screen
```

---

## 10. Author Profile Flow (Other Users)

```
Author Profile Screen
    │
    ├─► Tap "Follow" / "Unfollow" (app bar) → Toggle follow
    │
    ├─► Tap current city (in card) → City Detail Screen
    │
    ├─► Tap "Countries" card → Visited Countries Map (read-only; no edit)
    │
    ├─► Tap "Trips" card → Trips Screen for that author (itineraries list)
    │
    ├─► Tap past city chip → City Detail Screen
    │
    ├─► Tap QR code (app bar) → Profile QR View Screen
    │
    ├─► Tap itinerary card → Itinerary Detail
    │       ├─► Tap like → Toggle like (others' posts only)
    │       └─► Tap bookmark → Toggle bookmark
    │
    └─► Tap travel style chip → (display only)
```

---

## 11. City Detail Flow

```
City Detail Screen
    │
    ├─► If own profile:
    │       ├─► Add spot (per category) → Google Places → Save
    │       ├─► Edit spot → Update
    │       └─► Remove spot
    │
    └─► Tap spot → Open in Google Maps / Apple Maps
```

---

## 12. My Trips Flow

```
My Trips Screen (own: /profile/trips | author: /trips/:userId)
    │
    ├─► Tap card → Itinerary Detail
    ├─► Tap edit (own trips only) → Create Itinerary Screen (edit mode)
    ├─► Tap like (others' trips only) → Toggle like
    └─► Empty state (own trips) → "Create Trip" button → Create Itinerary Screen
```

---

## 13. Followers Flow

```
Followers Screen
    │
    └─► Tap user → Author Profile Screen
```

---

## 14. Likes Flow

```
Like Action (on Home Feed, Itinerary Detail, Search, Author Profile)
    │
    ├─► Tap thumbs up icon (others' posts only)
    │       │
    │       ├─► If not liked:
    │       │       ├─► Icon fills (primary color)
    │       │       ├─► Like count increments
    │       │       └─► Like saved to database
    │       │
    │       └─► If liked:
    │               ├─► Icon becomes outline
    │               ├─► Like count decrements
    │               └─► Like removed from database
    │
    └─► Like count displayed below icon (if > 0)
```

**State Sync:** When navigating back from Itinerary Detail, like state syncs to home feed automatically.

---

## 15. Translation Flow

```
Translation (on Home Feed, Itinerary Detail, Profile Screens)
    │
    ├─► Content detected as different language → Translate button appears
    │       │
    │       ├─► Tap translate button
    │       │       │
    │       │       ├─► Shows loading indicator
    │       │       ├─► Content translates to app language
    │       │       └─► Button becomes toggle
    │       │
    │       └─► Tap again (when translated)
    │               └─► Shows original content
    │
    └─► If content same as app language → No translate button shown
```

---

## 16. QR Code Flow

```
Profile QR Screen (/profile/qr)
    │
    ├─► Tab: "My code"
    │       ├─► QR code displayed
    │       ├─► Profile name shown
    │       ├─► Share link button → Copy/share profile link
    │       └─► Link works even without app installed
    │
    └─► Tab: "Scan"
            ├─► Camera scanner opens
            ├─► Scan QR code → Detects /author/:id link
            └─► Navigates to Author Profile Screen
```

**QR View Screen** (`/author/:id/qr`): View-only screen showing another user's QR code and share link.

---

## 17. Settings Flow

```
Settings Screen (/profile/settings)
    │
    ├─► Appearance section
    │       ├─► Light → Set light theme
    │       ├─► Dark → Set dark theme
    │       └─► System → Match device settings
    │
    ├─► Language section
    │       ├─► English → Set English
    │       ├─► Español → Set Spanish
    │       ├─► Français → Set French
    │       ├─► Deutsch → Set German
    │       └─► Italiano → Set Italian
    │
    └─► Account section
            └─► Sign out → Welcome Screen
```

---

## 18. Share Flow

```
Share Action (on Itinerary Detail, Profile QR)
    │
    ├─► Tap share button
    │       │
    │       ├─► Itinerary share → Share link: /itinerary/:id
    │       │       └─► Opens native share sheet
    │       │
    │       └─► Profile share → Share link: /author/:id
    │               └─► Opens native share sheet
    │
    └─► Recipient opens link → Deep link navigates to itinerary/profile
```

---

## 19. Auth & Redirect Rules

| State              | Route              | Redirect to   |
|--------------------|--------------------|---------------|
| Not logged in      | Any (except /, /auth) | / (Welcome) |
| Logged in, no onboarding | Any            | /onboarding   |
| Logged in, onboarding done | /             | /home         |
| Logged in, onboarding done | /onboarding | /home         |

---

## 20. Route Reference

| Path                 | Screen                 |
|----------------------|------------------------|
| `/`                  | Welcome                |
| `/auth/email`        | Email Auth             |
| `/onboarding`        | Onboarding             |
| `/home`              | Home                   |
| `/search`            | Search                 |
| `/create`            | Create Itinerary       |
| `/saved`             | Saved                  |
| `/profile`           | Profile                |
| `/itinerary/:id`     | Itinerary Detail       |
| `/itinerary/:id/edit`| Create Itinerary (edit)|
| `/author/:id`       | Author Profile         |
| `/author/:id/qr`     | Profile QR View        |
| `/city/:cityName`    | City Detail            |
| `/map/countries`     | Visited Countries Map  |
| `/profile/trips`     | My Trips (own)         |
| `/trips/:userId`     | Trips (author)         |
| `/profile/followers` | Followers              |
| `/profile/qr`        | Profile QR (own)       |
| `/profile/settings`  | Settings               |

---

## 21. State Sync Flow

```
State Sync (Like & Bookmark)
    │
    ├─► User likes/bookmarks on Itinerary Detail
    │       │
    │       └─► User navigates back (back button or swipe)
    │               │
    │               └─► Itinerary Detail pops with state: {liked, likeCount, bookmarked}
    │                       │
    │                       └─► Home Feed receives state
    │                               │
    │                               └─► Updates like/bookmark state in feed
    │                                       └─► UI updates automatically
```

This ensures the home feed always reflects the current like and bookmark state when users return from viewing an itinerary.
