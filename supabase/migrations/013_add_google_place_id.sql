-- Add google_place_id to store Google Places API place IDs (ChIJ...)
-- Used to open the place in Google Maps with its pin selected
ALTER TABLE itinerary_stops ADD COLUMN IF NOT EXISTS google_place_id TEXT;
