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
    ├─► Scroll → Load more (infinite scroll)
    ├─► Pull to refresh → Reload feed
    │
    ├─► Tap itinerary card
    │       └─► Itinerary Detail Screen
    │
    ├─► Tap author name
    │       └─► Author Profile Screen
    │
    └─► Tap bookmark icon
            └─► Toggle bookmark (stays on Home)
```

---

## 5. Create Itinerary Flow (7 Steps)

```
Create Itinerary Screen
    │
    ├─► Step 1: Start New Trip
    │       ├─► Enter title
    │       ├─► Select destination (Google Places)
    │       ├─► Select mode (solo/couple/friends/family)
    │       ├─► Select visibility (public/private)
    │       └─► Tap "Next"
    │
    ├─► Step 2: Add Destinations
    │       ├─► Add cities/towns (Google Places)
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
    ├─► Tap bookmark → Toggle bookmark
    │
    ├─► Tap spot on map → Open in Google Maps / Apple Maps
    │
    ├─► Tap "Edit" (own itinerary) → Create Itinerary Screen (edit mode)
    │
    └─► Tap "Use this trip" → Fork into Planning → Create Itinerary Screen (pre-filled)
```

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
    │       ├─► Type query → Search profiles
    │       ├─► Tap profile → Author Profile Screen
    │       └─► Tap follow/unfollow → Toggle follow
    │
    └─► Tab: Itineraries
            ├─► Type query → Search itineraries
            ├─► Set filters (days, styles, mode)
            ├─► Tap card → Itinerary Detail
            └─► Tap author → Author Profile Screen
```

---

## 9. Profile Flow (Own)

```
Profile Screen
    │
    ├─► Tap edit (name) → Inline edit → Save
    ├─► Tap edit (styles) → Select styles → Save
    │
    ├─► Current city
    │       ├─► Tap city → City Detail Screen
    │       └─► Edit top spots (Eat, Drink, Date, Chill)
    │
    ├─► Past cities
    │       ├─► Add city (Google Places)
    │       ├─► Tap city → City Detail Screen
    │       └─► Remove city
    │
    ├─► Tap "Visited countries" / map link → Visited Countries Map Screen
    │       └─► Edit → Country picker → Save → Back to Profile
    │
    ├─► Tap "My Trips" → My Trips Screen
    │
    ├─► Tap "Followers" → Followers Screen
    │
    └─► Tap "Sign out" → Welcome Screen
```

---

## 10. Author Profile Flow (Other Users)

```
Author Profile Screen
    │
    ├─► Tap "Follow" / "Unfollow" → Toggle follow
    │
    ├─► Tap current city → City Detail Screen (read-only if not own)
    │
    └─► Tap past city → City Detail Screen
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
My Trips Screen
    │
    ├─► Tap card → Itinerary Detail
    ├─► Tap edit → Create Itinerary Screen (edit mode)
    └─► Tap delete → Confirm → Remove itinerary
```

---

## 13. Followers Flow

```
Followers Screen
    │
    └─► Tap user → Author Profile Screen
```

---

## 14. Auth & Redirect Rules

| State              | Route              | Redirect to   |
|--------------------|--------------------|---------------|
| Not logged in      | Any (except /, /auth) | / (Welcome) |
| Logged in, no onboarding | Any            | /onboarding   |
| Logged in, onboarding done | /             | /home         |
| Logged in, onboarding done | /onboarding | /home         |

---

## 15. Route Reference

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
| `/city/:cityName`    | City Detail            |
| `/map/countries`     | Visited Countries Map  |
| `/profile/trips`     | My Trips               |
| `/profile/followers` | Followers              |
