-- Index for profile name search (pg_trgm already enabled in 001)
CREATE INDEX IF NOT EXISTS idx_profiles_name_trgm ON profiles USING gin (name gin_trgm_ops);

-- RPC to search profiles with stats (trips count, followers count)
CREATE OR REPLACE FUNCTION search_profiles_with_stats(
  search_query TEXT DEFAULT NULL,
  result_limit INT DEFAULT 30
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  photo_url TEXT,
  trips_count BIGINT,
  followers_count BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    p.id,
    p.name,
    p.photo_url,
    (SELECT COUNT(*)::BIGINT FROM itineraries i WHERE i.author_id = p.id) AS trips_count,
    (SELECT COUNT(*)::BIGINT FROM follows f WHERE f.following_id = p.id) AS followers_count
  FROM profiles p
  WHERE p.onboarding_complete = true
    AND (search_query IS NULL OR search_query = '' OR p.name ILIKE '%' || search_query || '%')
  ORDER BY (SELECT COUNT(*) FROM follows f WHERE f.following_id = p.id) DESC, p.name
  LIMIT result_limit;
$$;
