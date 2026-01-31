-- Add day column to itinerary_stops for day-by-day organization
ALTER TABLE itinerary_stops ADD COLUMN IF NOT EXISTS day INTEGER DEFAULT 1;

-- Expand category to include bar, cafe, attraction (fix existing invalid values first)
UPDATE itinerary_stops
SET category = 'attraction'
WHERE category IS NOT NULL
  AND category NOT IN ('restaurant', 'hotel', 'experience', 'bar', 'cafe', 'attraction');

ALTER TABLE itinerary_stops DROP CONSTRAINT IF EXISTS itinerary_stops_category_check;
ALTER TABLE itinerary_stops ADD CONSTRAINT itinerary_stops_category_check
  CHECK (category IS NULL OR category IN ('restaurant', 'hotel', 'experience', 'bar', 'cafe', 'attraction'));
