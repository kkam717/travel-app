-- Clear all trips data (itineraries, stops, bookmarks)
-- itinerary_stops and bookmarks cascade when itineraries are deleted

TRUNCATE itineraries CASCADE;
