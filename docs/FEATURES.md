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

- **Header** — Photo, name, stats (Countries visited, Trips, Followers)
- **Edit name** — Inline edit
- **Edit travel styles** — Multi-select styles
- **Current city** — Google Places autocomplete (locality)
- **Top spots (current city)** — Eat, Drink, Date, Chill categories
- **Add/edit top spots** — Google Places autocomplete per category
- **Past cities** — Add/remove via Google Places autocomplete
- **Past city top spots** — Per-city top spots
- **Visited countries** — List with link to map
- **Visited countries map** — `/map/countries?codes=...`
- **My Trips** — Link to `/profile/trips`
- **Followers** — Link to `/profile/followers`
- **Sign out** — App bar action

---

## Author Profile (Other Users)

- **View-only** — Name, photo, stats
- **Current city** — With top spots
- **Past cities** — With top spots
- **Follow / Unfollow** — Toggle follow
- **City detail** — Tap city to open `/city/:cityName?userId=...`

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
- **Edit mode** — Modify visited countries via country picker
- **Save** — Updates profile and refreshes map
- **Access** — From profile or direct route `/map/countries?codes=...`

---

## My Trips

- **Own itineraries** — List of user-created itineraries
- **Card actions** — View, edit, delete
- **Empty state** — Message when no trips

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
