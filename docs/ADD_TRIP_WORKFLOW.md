# Add a Trip — Full Workflow

This document describes the end-to-end flow for adding (creating) a new trip in the Travel App.

---

## 1. Entry points

The user can start adding a trip from:

| Location | Action | Route |
|----------|--------|--------|
| **Bottom nav** | Tap the green **+** (FAB) | `context.go('/create')` |
| **Profile** (no trips yet) | Tap "Create your first trip to get started" | `context.push('/create')` |
| **My Trips** (empty) | Tap "Create Trip" button | `context.go('/create')` |
| **Saved → Planning** (empty) | Tap "Create Trip" | `context.push('/create')` |

The create flow is implemented by **`CreateItineraryScreen`** (`lib/screens/create_itinerary_screen.dart`) with no `itineraryId` (edit flow uses the same screen with `itineraryId` and route `/itinerary/:id/edit`).

---

## 2. Create flow — 7 steps (PageView)

The screen uses a non-scrollable `PageView` with 7 pages. The user moves **Next** (or **Back**). Validation runs before advancing from steps 1–3.

### Step 1 — **New Trip** (Start a New Trip)

**Purpose:** Basic trip metadata and duration.

- **Trip name** (required): Text field, hint e.g. "Summer in Asia".
- **Countries visited**: Search and add countries (chips). At least one country is required to proceed.
- **Trip duration**, one of:
  - **Dates**: Start date + end date (date pickers). Days count = end − start + 1.
  - **Month/Season**: Season (Spring/Summer/Fall/Winter) and/or month (Jan–Dec), year dropdown, and a **number of days** field (default 7).
- **Travel style (mode):** Budget / Standard / Luxury (FilterChips).
- **Visibility:** Followers only / Public (SegmentedButton).

**Validation before Next:**

- Trip name non-empty (form validator).
- At least one country selected; else snackbar: "Add at least one country".
- If using dates: start and end date both set; else snackbar: "Select start and end dates".
- If using month/season: days ≥ 1; else snackbar: "Enter number of days".

**Next button label:** "Next: Add destinations".

---

### Step 2 — **Add destinations**

**Purpose:** Define which cities/places are visited (order is refined in Step 3 via day assignment).

- List of **destination cards**. Each card has:
  - A **PlacesField** (search city or location), optionally scoped to the selected countries, that sets name + lat/lng + optional external URL.
  - Or a chip showing the chosen place name (with option to clear and search again).
  - Remove-destination control.
- **Add destination** button to append another card.

**Validation before Next:**

- At least one destination has a non-empty name; else snackbar: "Add at least one destination".

**Next button label:** "Next: Assign days".

---

### Step 3 — **Assign days**

**Purpose:** For each destination, choose which day(s) the user was there (supports non-contiguous days, e.g. Day 1 and Day 5 in the same city).

- For each destination (with a name), a card showing:
  - Destination name.
  - Row of **Day 1**, **Day 2**, … **Day N** (N = trip days from Step 1) as FilterChips; tap to toggle.
  - "Selected: …" summary of selected days.

**Validation before Next:**

- Every destination that has a name must have at least one day selected; else snackbar: "Select at least one day for every destination".

**Next button label:** "Next: View map".

---

### Step 4 — **Trip map**

**Purpose:** Confirm the route on a map.

- **ItineraryMap** showing locations (and optional venue pins) in chronological order (day order, then destination order per day).
- If no locations have lat/lng, a placeholder message: "Add destinations with locations to see the map".
- List of destinations with their day ranges (e.g. "Tokyo (Days 1, 2, 3)").

No validation; informational only.

**Next button label:** "Next: Add transport".

---

### Step 5 — **Add transport**

**Purpose:** For each *segment* between two different destinations (in day order), optionally set how the user traveled and an optional description.

- Segments are derived from **chronological (destination, day) pairs**: e.g. Tokyo Day 1 → Kyoto Day 2 → Tokyo Day 5 yields segments Tokyo→Kyoto and Kyoto→Tokyo.
- For each segment, a card with:
  - "From (Place) (Day X)" → "To (Place) (Day Y)".
  - Transport type chips: **Plane**, **Train**, **Car**, **Bus**, **Boat**, **Walk**, **Other**, **Skip**.
  - Optional description field (e.g. "Flight BA 123").
- If only one destination or all same place: message "Same place — no transport" or "Add at least 2 destinations for transport".

No validation; user can skip or leave as "Skip".

**Next button label:** "Next: Add details".

---

### Step 6 — **Add details**

**Purpose:** Per (destination, day), optionally add venues (restaurants, hotels, guides, drinks).

- One **editable location card** per (destination, day) in chronological order:
  - Day badge.
  - Destination name.
  - Buttons: **Restaurant**, **Hotel**, **Guide**, **Drinks** — each adds a venue slot.
  - Each venue slot: **PlacesField** to search and set name + lat/lng + URL, or a chip once set; remove control.
- Between cards, a **TimelineConnector** showing the chosen transport type for the previous segment.

No validation; details are optional.

**Next button label:** "Next: Review trip".

---

### Step 7 — **Review trip**

**Purpose:** Final summary and save.

- **Map** (same as Step 4) at the top.
- **List:** "All destinations and details" — each (destination, day) and under it the venues (with category label: restaurant, hotel, guide, drinks).
- **Edit details** button → goes back to Step 6 (Add details).
- **Save Trip** button → calls `_save()`.

---

## 3. Back / exit behavior

- **Back button (per step):** If there is unsaved data (title, countries, any destination name, or any venue name), a dialog asks "Discard changes?" (Cancel / Discard). If user confirms Discard, navigates to previous step (or exits if on step 1).
- **Android back / PopScope:** Same logic: if step > 0, run back logic (with discard dialog when needed); if step 0 and unsaved data, show discard dialog then pop or `context.go('/home')` if not poppable.

---

## 4. Save (new trip)

**When:** User taps **Save Trip** on Step 7 (Review).

**Computation:**

1. **Destination string:** `_selectedCountries` → country names from `countries` map → joined by `", "` (e.g. `"Japan, South Korea"`).
2. **Stops (chronological):** From `_chronologicalDestDayPairs` (each destination-day pair in order), build `stopsData`:
   - For each pair: one **location** stop (name, category `location`, stop_type `location`, lat, lng, external_url, day, position).
   - Then for that (destination, day), append **venue** stops (name, category e.g. restaurant/hotel/experience, stop_type `venue`, lat, lng, external_url, day, position).
3. **Transport transitions:** If there are at least 2 chronological pairs, build a list of `TransportTransition` (type + optional description) between consecutive pairs (one per segment).

**API (new trip):**

- `SupabaseService.createItinerary(...)` with:
  - `authorId` (current user),
  - `title`, `destination`, `daysCount`, `styleTags` (empty for new), `mode`, `visibility`, `forkedFromId: null`,
  - `stopsData`,
  - `useDates`, `startDate`, `endDate` (if dates mode),
  - `durationYear`, `durationMonth`, `durationSeason` (if month/season mode),
  - `transportTransitions`.
- Backend inserts into `itineraries` then inserts each stop into `itinerary_stops` (with `itinerary_id` and `position`).

**After success:**

- Analytics: `itinerary_created` with `id`.
- Navigate: `context.go('/itinerary/${it.id}')` → **Itinerary detail screen**.

**On error:**

- Snackbar: "Could not save" (or localized equivalent).

---

## 5. Edit flow (same screen, different route)

- **Route:** `/itinerary/:id/edit` → `CreateItineraryScreen(itineraryId: id)`.
- **Load:** In `initState`, `_loadForEdit()` fetches the itinerary (with access check), then fills all form state (title, countries, dates/duration, destinations, days per destination, venues per day, transport).
- **Save:** `_save()` calls `SupabaseService.updateItinerary(id, updateData)` and `SupabaseService.updateItineraryStops(id, stopsData)` (replace-all stops for that itinerary), then `context.go('/itinerary/$id')`.

---

## 6. Data model summary

- **Itinerary:** title, destination (string of country names), days_count, mode, visibility, use_dates, start_date, end_date, duration_year/month/season, transport_transitions (JSON array).
- **Stops:** itinerary_id, position, day, name, category, stop_type (`location` | `venue`), lat, lng, external_url; venues use category like restaurant, hotel, experience (guide).

---

## 7. File reference

| What | File / symbol |
|------|----------------|
| Create/Edit screen | `lib/screens/create_itinerary_screen.dart` — `CreateItineraryScreen` |
| Create route | `lib/router.dart` — `/create`, `/itinerary/:id/edit` |
| FAB → create | `lib/screens/main_shell.dart` — `context.go('/create')` |
| Create API | `lib/services/supabase_service.dart` — `createItinerary`, `updateItinerary`, `updateItineraryStops` |
| Countries | `lib/data/countries.dart` — `countries`, `destinationToCountryCodes` |
| Map widget | `lib/widgets/itinerary_map.dart` |
| Places search | `lib/widgets/places_field.dart` |

---

## 8. Flow diagram (high level)

```
[Home / Profile / Saved / My Trips]
         │
         ▼ Tap + or "Create Trip"
    ┌────────────┐
    │  /create   │  CreateItineraryScreen (no id)
    └────────────┘
         │
         ▼ Step 1: New Trip (title, countries, duration, mode, visibility)
         ▼ Step 2: Add destinations (places)
         ▼ Step 3: Assign days (per destination)
         ▼ Step 4: Trip map (preview)
         ▼ Step 5: Add transport (between segments)
         ▼ Step 6: Add details (venues per day)
         ▼ Step 7: Review → [Save Trip]
         │
         ▼ SupabaseService.createItinerary + stops
         │
         ▼ context.go('/itinerary/:id')
    ┌────────────────────┐
    │ Itinerary detail   │
    └────────────────────┘
```

This is the full workflow for adding a trip from entry to saved itinerary detail.
