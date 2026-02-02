-- Optional columns for remembering duration preferences when editing
-- use_dates: true = Dates mode, false = Month/Season mode
-- start_date, end_date: when use_dates = true
-- duration_year, duration_month, duration_season: when use_dates = false
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS use_dates BOOLEAN;
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS duration_year INTEGER;
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS duration_month INTEGER;
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS duration_season TEXT;
