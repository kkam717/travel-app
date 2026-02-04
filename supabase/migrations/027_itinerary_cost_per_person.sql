-- Optional trip cost per person (USD) for itineraries
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS cost_per_person INTEGER;
