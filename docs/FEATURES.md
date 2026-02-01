# Travel App — Full Feature List

## Authentication

- **Email sign-up** — Create account with email and password
- **Email sign-in** — Sign in with existing credentials
- **Sign out** — Log out from any screen (Welcome, Onboarding)
- **Session persistence** — Supabase handles session; users stay logged in
- **Auth redirect** — Deep links for email verification (when enabled in Supabase)

---

## Onboarding

- **Multi-step onboarding** — 3 steps for new users
- **Step 1: Your name** — Enter display name
- **Step 2: Countries visited** — Searchable country picker with checkboxes
- **Step 3: Travel preferences** — Select travel styles (e.g. adventure, foodie) and mode (e.g. solo, couple)
- **Skip / Sign out** — Option to sign out during onboarding
- **Completion** — Profile saved; user redirected to Home

---

## Navigation & Shell

- **Bottom navigation** — Home, Search, Saved, Profile
- **Floating Action Button (FAB)** — Create new itinerary (navigates to Create)
- **go_router** — Client-side routing with auth/onboarding redirects
- **Shell route** — Main tabs share a persistent shell

---

## Home Feed

- **Personalized feed** — Itineraries from followed users + own itineraries
- **Discover section** — Public itineraries for users with few/no follows
- **Infinite scroll** — Paginated feed (20 per page)
- **Feed cards** — Title, destination, days, styles, mode, author, static map preview
- **Bookmark toggle** — Bookmark/unbookmark from feed
- **Tap to view** — Open itinerary detail
- **Tap author** — Open author profile
- **Home cache** — Cached feed for faster initial load
- **Pull to refresh** — Reload feed

---

## Itinerary Creation & Editing

- **7-step create flow** — Guided workflow for new itineraries
- **Edit mode** — Same flow for editing existing itineraries (`/itinerary/:id/edit`)

### Step 1: Start New Trip

- **Title** — Free-text trip title
- **Destination** — Google Places autocomplete (locality)
- **Mode** — Solo, couple, friends, family
- **Visibility** — Public or private

### Step 2: Add Destinations

- **Google Places autocomplete** — Add cities/towns (location stops)
- **Reorder** — Drag to reorder destinations
- **Remove** — Delete destinations

### Step 3: Assign Days

- **Day assignment** — Assign each destination to a day
- **Day grouping** — Stops grouped by day

### Step 4: Trip Map

- **Interactive map** — Preview route with pins
- **Layout** — Map + list of stops by day

### Step 5: Add Details

- **Venue stops** — Add restaurants, bars, hotels, guides via Google Places
- **Categories** — eat, drink, hotel, guide
- **Assign to destination** — Each venue linked to a location stop
- **Reorder venues** — Within each destination
- **Remove venues** — Delete individual venues

### Step 6: Review Trip

- **Summary** — Title, destination, days, stops
- **Edit links** — Jump back to any step

### Step 7: Save Trip

- **Create / Update** — Save new or update existing itinerary
- **Fork support** — Forked itineraries retain `forked_from_itinerary_id`

---

## Itinerary Detail

- **Full view** — Title, author, destination, days, styles, mode
- **Map** — Interactive map with route and pins (primary theme color)
- **Stops by day** — Grouped list of locations and venues
- **Open in Maps** — Tap spot to open in Google Maps or Apple Maps (prefers Place ID when available)
- **Bookmark** — Bookmark/unbookmark
- **Edit** — Edit own itineraries
- **View author** — Tap author to open profile
- **Planning** — "Use this trip" forks itinerary into Planning

---

## Saved Screen

- **Two tabs** — Bookmarked, Planning
- **Bookmarked** — Itineraries user has bookmarked
- **Planning** — Itineraries user has forked (in progress)
- **Card actions** — View detail, remove bookmark, delete from planning
- **Empty states** — Messages when tabs are empty

---

## Search

- **Two tabs** — Profiles, Itineraries
- **Profiles tab** — Search by name
- **Profile results** — Name, follower count, follow/unfollow
- **Itineraries tab** — Search by keyword
- **Itinerary filters** — Days, styles, mode
- **Debounced search** — 400ms debounce for itinerary search
- **Empty query** — Shows empty results
- **Tap result** — Open profile or itinerary detail

---

## Profile (Own)

- **Layout** — Matches author profile: card with avatar + current city, Countries/Trips stats, Followers/Following bar, Past cities, Travel styles
- **Profile card** — Avatar (tap to upload photo) + current city (tap to open city page)
- **Countries card** — Opens visited countries map with edit enabled (`/map/countries?codes=...&editable=1`)
- **Trips card** — Opens My Trips page (`/profile/trips`); itineraries are shown only on Trips page, not on profile
- **Followers/Following bar** — Tappable; opens Followers screen (`/profile/followers`)
- **Past cities** — Add/remove via edit sheet; tap city to open city detail
- **Travel styles** — Edit via edit sheet
- **Edit button** — App bar; opens edit sheet for name, current city, past cities, travel styles
- **Sign out** — App bar action

---

## Author Profile (Other Users)

- **Layout** — Card with avatar + current city, Countries/Trips stats, Followers/Following bar, Past cities, Travel styles
- **Profile card** — Avatar + current city (tap to open city detail page)
- **Countries card** — Opens visited countries map (read-only; no edit option)
- **Trips card** — Opens author's Trips page (`/trips/:userId`); itineraries are shown only on Trips page, not on profile
- **Followers/Following bar** — Displays counts
- **Past cities** — Tappable chips; open city detail
- **Travel styles** — Display only
- **Follow / Unfollow** — App bar button

---

## City Detail

- **Route** — `/city/:cityName?userId=...`
- **Top spots by category** — Eat, Drink, Date, Chill
- **Edit (own profile)** — Add/edit/remove spots via Google Places
- **View (other profile)** — Read-only
- **Map links** — Open spot in Google/Apple Maps

---

## Visited Countries Map

- **World map** — Countries highlighted by visited list
- **Edit mode (own profile)** — When opened from own profile (`editable=1`), edit button visible; modify visited countries via country picker
- **Read-only (other profiles)** — When opened from author profile, no edit button
- **Save** — Updates profile and refreshes map (own profile only)
- **Access** — From profile (`/map/countries?codes=...&editable=1`) or author profile (`/map/countries?codes=...`)

---

## My Trips

- **Own itineraries** — `/profile/trips` — List of user-created itineraries
- **Author itineraries** — `/trips/:userId` — List of another user's itineraries (opened from author profile)
- **Card actions** — View, edit (own trips only)
- **Empty state** — Message when no trips; "Create Trip" button for own trips

---

## Followers

- **Follower list** — Users who follow the current user
- **Tap** — Open author profile
- **Follow status** — Shown per user

---

## Technical Features

- **Supabase** — Auth, database, storage, RLS
- **Google Places API** — Autocomplete, place details, geocoding
- **Flutter** — Cross-platform (iOS, Android, Web)
- **Analytics** — Screen views and events
- **Theme** — App-wide theme (colors, spacing)
- **Map styling** — Custom map styles for itinerary maps
- **Feed visibility** — Mutual-follow logic for feed content
- **Search** — Profile and itinerary search with filters
- **Bookmark counts** — Denormalized bookmark counts on itineraries

---

## Data Models

- **Profile** — name, photo, visited_countries, travel_styles, travel_mode, current_city, past_cities, top_spots, onboarding_complete
- **Itinerary** — title, destination, days_count, style_tags, mode, visibility, author_id, forked_from_itinerary_id
- **ItineraryStop** — position, day, name, category, stop_type (location/venue), lat, lng, google_place_id
- **UserCity** — current_city, past_cities with top spots (eat, drink, date, chill)
- **Follows** — follower_id, followed_id
- **Bookmarks** — user_id, itinerary_id
- **Planning** — Forked itineraries (forked_from_itinerary_id set)
