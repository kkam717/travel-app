-- Remove favourite countries, places lived, and ideas/future trips from profiles
ALTER TABLE profiles DROP COLUMN IF EXISTS favourite_countries;
ALTER TABLE profiles DROP COLUMN IF EXISTS cities_lived;
ALTER TABLE profiles DROP COLUMN IF EXISTS ideas_future_trips;
