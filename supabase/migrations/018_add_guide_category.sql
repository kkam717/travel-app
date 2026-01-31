-- Add 'guide' to itinerary_stops category (for tour guides, local guides)
ALTER TABLE itinerary_stops DROP CONSTRAINT IF EXISTS itinerary_stops_category_check;
ALTER TABLE itinerary_stops ADD CONSTRAINT itinerary_stops_category_check
  CHECK (category IS NULL OR category IN ('location', 'restaurant', 'hotel', 'experience', 'bar', 'cafe', 'attraction', 'guide'));
