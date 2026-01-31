-- Add stop_type to distinguish day-level locations (cities/towns) from venues (restaurants, bars, hotels)
ALTER TABLE itinerary_stops ADD COLUMN IF NOT EXISTS stop_type TEXT DEFAULT 'venue' CHECK (stop_type IN ('location', 'venue'));

-- Add 'location' to category for day-level places (city, town, village)
UPDATE itinerary_stops
SET category = 'attraction'
WHERE category IS NOT NULL
  AND category NOT IN ('location', 'restaurant', 'hotel', 'experience', 'bar', 'cafe', 'attraction');

ALTER TABLE itinerary_stops DROP CONSTRAINT IF EXISTS itinerary_stops_category_check;
ALTER TABLE itinerary_stops ADD CONSTRAINT itinerary_stops_category_check
  CHECK (category IS NULL OR category IN ('location', 'restaurant', 'hotel', 'experience', 'bar', 'cafe', 'attraction'));
