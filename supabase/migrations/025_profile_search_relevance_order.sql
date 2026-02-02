-- Re-apply profile search ordering by relevance so results like "Mateo Alvarez"
-- appear before "_luca_crema_" when searching "ma" (starts-with, then position, then name).
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
  ORDER BY
    -- 1) Names that start with the query first (0), then contain only (1)
    CASE WHEN (search_query IS NULL OR search_query = '') THEN 0
         WHEN p.name ILIKE search_query || '%' THEN 0
         ELSE 1 END,
    -- 2) Then by position of match (earlier match = higher rank); no match (0) sorts last
    CASE WHEN (search_query IS NULL OR search_query = '') THEN 1
         ELSE NULLIF(position(lower(search_query) IN lower(p.name)), 0) END NULLS LAST,
    -- 3) Then alphabetically by name
    p.name ASC NULLS LAST
  LIMIT result_limit;
$$;
