-- RPC to get bookmark counts per itinerary (for social proof)
-- SECURITY DEFINER allows reading counts without exposing who bookmarked
CREATE OR REPLACE FUNCTION get_bookmark_counts(p_itinerary_ids UUID[])
RETURNS TABLE (itinerary_id UUID, bookmark_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT b.itinerary_id, COUNT(*)::BIGINT
  FROM bookmarks b
  WHERE b.itinerary_id = ANY(p_itinerary_ids)
  GROUP BY b.itinerary_id;
$$;
