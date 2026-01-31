-- Follows table for social feed
CREATE TABLE IF NOT EXISTS follows (
  follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view follows" ON follows;
DROP POLICY IF EXISTS "Users can follow others" ON follows;
DROP POLICY IF EXISTS "Users can unfollow" ON follows;

CREATE POLICY "Users can view follows" ON follows FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can follow others" ON follows FOR INSERT TO authenticated WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow" ON follows FOR DELETE TO authenticated USING (auth.uid() = follower_id);

-- Extend itineraries RLS: allow viewing friends' itineraries when user follows author
DROP POLICY IF EXISTS "Public itineraries viewable by authenticated" ON itineraries;

CREATE POLICY "Public itineraries viewable by authenticated" ON itineraries FOR SELECT TO authenticated
  USING (
    visibility = 'public'
    OR (visibility = 'private' AND author_id = auth.uid())
    OR (visibility = 'friends' AND author_id = auth.uid())
    OR (visibility = 'friends' AND EXISTS (
      SELECT 1 FROM follows f WHERE f.follower_id = auth.uid() AND f.following_id = itineraries.author_id
    ))
  );
