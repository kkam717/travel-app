# ChatGPT Prompt: Generate 4 Public Test Trips Per Profile (24 Total)

You are a SQL expert helping to create test data for a travel itinerary app. Generate SQL INSERT statements for **4 diverse public itineraries per test profile** (24 trips total) that showcase all the different features of the app.

## Database Schema

### Test Profiles (use these author_ids):
- `11111111-1111-1111-1111-111111111111` - Amelia Carter (London, Culture/Food/Nightlife, standard mode)
- `22222222-2222-2222-2222-222222222222` - Kenji Nakamura (Tokyo, Food/Culture/Nightlife, standard mode)
- `33333333-3333-3333-3333-333333333333` - Sofia Moretti (Milan, Culture/Relax/Food, luxury mode)
- `44444444-4444-4444-4444-444444444444` - Ethan Brooks (New York, Adventure/Food/Nightlife, budget mode)
- `55555555-5555-5555-5555-555555555555` - Nina Larsen (Copenhagen, Nature/Culture/Relax, standard mode)
- `66666666-6666-6666-6666-666666666666` - Mateo Alvarez (Barcelona, Food/Culture/Relax, budget mode)

### Itineraries Table Structure:
```sql
itineraries (
  id UUID PRIMARY KEY,
  author_id UUID NOT NULL,
  title TEXT NOT NULL,
  destination TEXT NOT NULL,
  days_count INTEGER NOT NULL,
  style_tags TEXT[] DEFAULT '{}',  -- Array of: 'Culture', 'Food', 'Nightlife', 'Adventure', 'Nature', 'Relax'
  mode TEXT CHECK (mode IN ('budget', 'standard', 'luxury')),
  visibility TEXT DEFAULT 'public' CHECK (visibility IN ('private', 'friends', 'public')),
  forked_from_itinerary_id UUID NULL,
  use_dates BOOLEAN,  -- true = use dates, false = use month/season
  start_date DATE,  -- when use_dates = true
  end_date DATE,  -- when use_dates = true
  duration_year INTEGER,  -- when use_dates = false
  duration_month INTEGER,  -- when use_dates = false (1-12)
  duration_season TEXT,  -- when use_dates = false ('spring', 'summer', 'fall', 'winter')
  transport_transitions JSONB,  -- Array: [{"type":"plane","description":"..."}, {"type":"train"}, ...]
  cost_per_person INTEGER,  -- USD, optional
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
)
```

### Itinerary Stops Table Structure:
```sql
itinerary_stops (
  id UUID PRIMARY KEY,
  itinerary_id UUID NOT NULL,
  day INTEGER NOT NULL,  -- Day number (1, 2, 3, ...)
  position INTEGER NOT NULL,  -- Position within day (0, 1, 2, ...)
  name TEXT NOT NULL,
  stop_type TEXT,  -- 'location' = city/town, 'venue' = restaurant/bar/hotel/experience
  category TEXT CHECK (category IN ('restaurant', 'hotel', 'experience')),
  external_url TEXT,  -- Optional URL
  lat DOUBLE PRECISION,  -- REQUIRED for location-based search
  lng DOUBLE PRECISION,  -- REQUIRED for location-based search
  google_place_id TEXT,  -- Optional
  rating INTEGER,  -- Optional 1-5 for venues
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

## Requirements

Create **4 diverse public itineraries for EACH of the 6 test profiles** (24 trips total) that showcase:

**For each profile, create 4 trips that together showcase:**

1. **Different travel modes**: Distribute trips across profiles so you have a good mix of 'budget', 'standard', and 'luxury' across all 24 trips
2. **Different style_tags combinations**: Use various combinations of: Culture, Food, Nightlife, Adventure, Nature, Relax. Match each profile's travel_styles where appropriate.
3. **Different duration formats** (across all 24 trips):
   - Some trips with `use_dates = true` (has start_date and end_date)
   - Some trips with `use_dates = false` (has duration_year, duration_month, or duration_season)
   - Some trips with neither (just days_count)
4. **Transport transitions**: Include `transport_transitions` JSONB array in multi-city trips
5. **Cost per person**: Include `cost_per_person` in some trips (especially luxury ones)
6. **Varied stop types**: Mix of 'location' stops (cities) and 'venue' stops (restaurants, hotels, experiences)
7. **All stops must have lat/lng**: Every stop needs coordinates for location-based search to work
8. **Realistic destinations**: Use real cities and places with accurate coordinates. Match destinations to each profile's visited_countries where possible.
9. **Different day counts**: Vary from 3-10 days across all trips
10. **Rating field**: Include venue stops with `rating` (1-5) in some trips

## Example Format

```sql
-- Trip 1: Budget Adventure Trip with Dates
INSERT INTO itineraries (id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person)
VALUES (
  gen_random_uuid(),
  '44444444-4444-4444-4444-444444444444',  -- Ethan (budget mode)
  'Thailand Backpacking Adventure',
  'Thailand',
  7,
  ARRAY['Adventure', 'Food', 'Nature'],
  'budget',
  'public',
  true,
  '2024-06-15',
  '2024-06-22',
  800
);

-- Stops for Trip 1
INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, lat, lng, rating)
VALUES
  (gen_random_uuid(), '<trip_id>', 1, 0, 'Bangkok', 'location', NULL, 13.7563, 100.5018, NULL),
  (gen_random_uuid(), '<trip_id>', 1, 1, 'Chatuchak Weekend Market', 'venue', 'experience', 13.8000, 100.5500, NULL),
  (gen_random_uuid(), '<trip_id>', 1, 2, 'Thip Samai', 'venue', 'restaurant', 13.7500, 100.5000, 5),
  -- ... more stops
;
```

## Output Format

Use **fixed UUIDs** for itinerary IDs so you can reference them in stops. Use this pattern:

```sql
-- Trip 1: Budget Adventure Trip with Dates, Transport Transitions, Cost
INSERT INTO itineraries (id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000001',  -- Fixed UUID
  '44444444-4444-4444-4444-444444444444',  -- Ethan (budget mode)
  'Thailand Backpacking Adventure',
  'Thailand',
  7,
  ARRAY['Adventure', 'Food', 'Nature'],
  'budget',
  'public',
  true,
  '2024-06-15',
  '2024-06-22',
  800,
  '[{"type":"plane","description":"Flight Bangkok to Phuket"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000001', 1, 0, 'Bangkok', 'location', NULL, 13.7563, 100.5018, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000001', 1, 1, 'Chatuchak Weekend Market', 'venue', 'experience', 13.8000, 100.5500, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000001', 1, 2, 'Thip Samai', 'venue', 'restaurant', 13.7500, 100.5000, 5),
  -- ... 5-10 stops total
;
```

Generate complete SQL with:
1. **24 INSERT statements for `itineraries` table** (4 per profile):
   - Use fixed UUIDs: `cccc0000-0000-0000-0000-000000000001` through `000024`
   - Distribute across all 6 profiles (4 trips each)
2. **24 corresponding INSERT statements for `itinerary_stops`** (5-10 stops per trip, each with lat/lng)
3. Use `gen_random_uuid()` for stop IDs only
4. Reference the fixed itinerary IDs in stops
5. Include comments explaining which features each trip demonstrates and which profile it belongs to
6. **Organize by profile** - group the 4 trips for each profile together with clear comments

## Important Notes

- All stops MUST have `lat` and `lng` coordinates (use real coordinates for real places)
- Mix location stops (cities) and venue stops (restaurants, hotels, experiences)
- Use realistic place names and coordinates
- Ensure `days_count` matches the actual number of days with stops
- For multi-city trips, include transport_transitions between cities
- Make trips diverse in style, duration, and features

Generate the complete SQL now.
