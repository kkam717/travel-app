-- Current City & Past Cities with Top Spots
-- Current city stored on profile; past cities in separate table; top spots per city/category

-- Add current_city to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_city TEXT;

-- Past cities (cities user previously lived in)
CREATE TABLE IF NOT EXISTS user_past_cities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  city_name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, city_name)
);

CREATE INDEX IF NOT EXISTS idx_user_past_cities_user ON user_past_cities(user_id);

-- Top spots per city (Eat, Drink, Date, Chill - max 5 each)
CREATE TABLE IF NOT EXISTS user_top_spots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  city_name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('eat', 'drink', 'date', 'chill')),
  name TEXT NOT NULL,
  description TEXT,
  location_url TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_top_spots_user_city ON user_top_spots(user_id, city_name);
CREATE INDEX IF NOT EXISTS idx_user_top_spots_category ON user_top_spots(user_id, city_name, category);

-- RLS
ALTER TABLE user_past_cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_top_spots ENABLE ROW LEVEL SECURITY;

-- Past cities: anyone authenticated can view; users can CRUD own
DROP POLICY IF EXISTS "Past cities viewable by authenticated" ON user_past_cities;
DROP POLICY IF EXISTS "Users can insert own past cities" ON user_past_cities;
DROP POLICY IF EXISTS "Users can update own past cities" ON user_past_cities;
DROP POLICY IF EXISTS "Users can delete own past cities" ON user_past_cities;
CREATE POLICY "Past cities viewable by authenticated" ON user_past_cities FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert own past cities" ON user_past_cities FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own past cities" ON user_past_cities FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own past cities" ON user_past_cities FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Top spots: anyone authenticated can view; users can CRUD own
DROP POLICY IF EXISTS "Top spots viewable by authenticated" ON user_top_spots;
DROP POLICY IF EXISTS "Users can insert own top spots" ON user_top_spots;
DROP POLICY IF EXISTS "Users can update own top spots" ON user_top_spots;
DROP POLICY IF EXISTS "Users can delete own top spots" ON user_top_spots;
CREATE POLICY "Top spots viewable by authenticated" ON user_top_spots FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert own top spots" ON user_top_spots FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own top spots" ON user_top_spots FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own top spots" ON user_top_spots FOR DELETE TO authenticated USING (auth.uid() = user_id);
