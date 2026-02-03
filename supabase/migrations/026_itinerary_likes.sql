-- Likes: users can like other people's itineraries (not their own).
-- Self-like is prevented in the app (like button only shown for others' posts).
-- Optional: enforce at DB with a trigger (see below).
CREATE TABLE IF NOT EXISTS itinerary_likes (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, itinerary_id)
);

-- Enforce no self-like at database level
CREATE OR REPLACE FUNCTION check_no_self_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM itineraries WHERE id = NEW.itinerary_id AND author_id = NEW.user_id) THEN
    RAISE EXCEPTION 'Cannot like your own itinerary';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_itinerary_likes_no_self ON itinerary_likes;
CREATE TRIGGER trg_itinerary_likes_no_self
  BEFORE INSERT ON itinerary_likes
  FOR EACH ROW EXECUTE PROCEDURE check_no_self_like();

CREATE INDEX IF NOT EXISTS idx_itinerary_likes_user ON itinerary_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_likes_itinerary ON itinerary_likes(itinerary_id);

ALTER TABLE itinerary_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view likes" ON itinerary_likes;
DROP POLICY IF EXISTS "Users can add own like" ON itinerary_likes;
DROP POLICY IF EXISTS "Users can remove own like" ON itinerary_likes;

CREATE POLICY "Users can view likes" ON itinerary_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can add own like" ON itinerary_likes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove own like" ON itinerary_likes FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- RPC to get like counts per itinerary (for display)
CREATE OR REPLACE FUNCTION get_like_counts(p_itinerary_ids UUID[])
RETURNS TABLE (itinerary_id UUID, like_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT l.itinerary_id, COUNT(*)::BIGINT
  FROM itinerary_likes l
  WHERE l.itinerary_id = ANY(p_itinerary_ids)
  GROUP BY l.itinerary_id;
$$;
