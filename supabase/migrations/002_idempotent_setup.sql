-- Idempotent migration: safe to run even if some objects already exist
-- Run this if 001 failed partway through

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tables (skip if exist)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  photo_url TEXT,
  visited_countries TEXT[] DEFAULT '{}',
  travel_styles TEXT[] DEFAULT '{}',
  travel_mode TEXT CHECK (travel_mode IN ('budget', 'standard', 'luxury')),
  favourite_countries TEXT[] DEFAULT '{}',
  cities_lived JSONB DEFAULT '[]',
  ideas_future_trips JSONB DEFAULT '[]',
  favourite_trip_title TEXT,
  favourite_trip_description TEXT,
  favourite_trip_link TEXT,
  onboarding_complete BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS places (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  country TEXT,
  city TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  category TEXT,
  external_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_places_name_trgm ON places USING gin (name gin_trgm_ops);

CREATE TABLE IF NOT EXISTS itineraries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  destination TEXT NOT NULL,
  days_count INTEGER NOT NULL,
  style_tags TEXT[] DEFAULT '{}',
  mode TEXT CHECK (mode IN ('budget', 'standard', 'luxury')),
  visibility TEXT NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'friends', 'public')),
  forked_from_itinerary_id UUID REFERENCES itineraries(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_itineraries_author ON itineraries(author_id);
CREATE INDEX IF NOT EXISTS idx_itineraries_visibility ON itineraries(visibility);
CREATE INDEX IF NOT EXISTS idx_itineraries_created ON itineraries(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_itineraries_destination ON itineraries USING gin (destination gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_itineraries_title ON itineraries USING gin (title gin_trgm_ops);

CREATE TABLE IF NOT EXISTS itinerary_stops (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  name TEXT NOT NULL,
  category TEXT CHECK (category IN ('restaurant', 'hotel', 'experience')),
  external_url TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  place_id UUID REFERENCES places(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_itinerary_stops_itinerary ON itinerary_stops(itinerary_id);

CREATE TABLE IF NOT EXISTS bookmarks (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, itinerary_id)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON bookmarks(user_id);

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE places ENABLE ROW LEVEL SECURITY;
ALTER TABLE itineraries ENABLE ROW LEVEL SECURITY;
ALTER TABLE itinerary_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

-- Policies (drop first for idempotency)
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

CREATE POLICY "Profiles are viewable by authenticated users" ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Places are viewable by authenticated users" ON places;
DROP POLICY IF EXISTS "Authenticated users can insert places" ON places;

CREATE POLICY "Places are viewable by authenticated users" ON places FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert places" ON places FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Public itineraries viewable by authenticated" ON itineraries;
DROP POLICY IF EXISTS "Users can insert own itineraries" ON itineraries;
DROP POLICY IF EXISTS "Users can update own itineraries" ON itineraries;
DROP POLICY IF EXISTS "Users can delete own itineraries" ON itineraries;

CREATE POLICY "Public itineraries viewable by authenticated" ON itineraries FOR SELECT TO authenticated
  USING (visibility = 'public' OR (visibility = 'private' AND author_id = auth.uid()));
CREATE POLICY "Users can insert own itineraries" ON itineraries FOR INSERT TO authenticated WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users can update own itineraries" ON itineraries FOR UPDATE TO authenticated USING (auth.uid() = author_id) WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users can delete own itineraries" ON itineraries FOR DELETE TO authenticated USING (auth.uid() = author_id);

DROP POLICY IF EXISTS "Stops viewable when itinerary is viewable" ON itinerary_stops;
DROP POLICY IF EXISTS "Users can manage stops for own itineraries" ON itinerary_stops;

CREATE POLICY "Stops viewable when itinerary is viewable" ON itinerary_stops FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM itineraries i WHERE i.id = itinerary_stops.itinerary_id AND (i.visibility = 'public' OR (i.visibility = 'private' AND i.author_id = auth.uid()))));
CREATE POLICY "Users can manage stops for own itineraries" ON itinerary_stops FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM itineraries i WHERE i.id = itinerary_stops.itinerary_id AND i.author_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM itineraries i WHERE i.id = itinerary_stops.itinerary_id AND i.author_id = auth.uid()));

DROP POLICY IF EXISTS "Users can view own bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can insert own bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can delete own bookmarks" ON bookmarks;

CREATE POLICY "Users can view own bookmarks" ON bookmarks FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own bookmarks" ON bookmarks FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own bookmarks" ON bookmarks FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Storage
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;

CREATE POLICY "Avatar images are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Users can upload own avatar" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users can update own avatar" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
