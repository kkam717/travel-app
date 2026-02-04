-- Optional 1–5 star rating for venue stops (restaurants, hotels, experiences, etc.)
ALTER TABLE itinerary_stops ADD COLUMN IF NOT EXISTS rating INTEGER CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5));
