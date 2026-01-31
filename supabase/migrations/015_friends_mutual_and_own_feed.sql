-- Friends visibility: only visible when both accounts follow each other (mutual friends)
-- Private: only author (remove follower access - truly private)
-- Own posts: appear on own feed (handled in app)
-- Search/feed: public + friends (when mutual) + own (all visibility for self)

-- 1. Update RLS: friends = mutual follow only; private = author only
DROP POLICY IF EXISTS "Public itineraries viewable by authenticated" ON itineraries;

CREATE POLICY "Public itineraries viewable by authenticated" ON itineraries FOR SELECT TO authenticated
  USING (
    visibility = 'public'
    OR (visibility = 'private' AND author_id = auth.uid())
    OR (visibility = 'friends' AND author_id = auth.uid())
    OR (visibility = 'friends' AND EXISTS (
      SELECT 1 FROM follows fa, follows fb
      WHERE fa.follower_id = auth.uid() AND fa.following_id = itineraries.author_id
        AND fb.follower_id = itineraries.author_id AND fb.following_id = auth.uid()
    ))
  );

-- 1b. Update itinerary_stops to match (stops follow itinerary visibility)
DROP POLICY IF EXISTS "Stops viewable when itinerary is viewable" ON itinerary_stops;

CREATE POLICY "Stops viewable when itinerary is viewable" ON itinerary_stops FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM itineraries i
      WHERE i.id = itinerary_stops.itinerary_id
        AND (
          i.visibility = 'public'
          OR (i.visibility = 'private' AND i.author_id = auth.uid())
          OR (i.visibility = 'friends' AND i.author_id = auth.uid())
          OR (i.visibility = 'friends' AND EXISTS (
            SELECT 1 FROM follows fa, follows fb
            WHERE fa.follower_id = auth.uid() AND fa.following_id = i.author_id
              AND fb.follower_id = i.author_id AND fb.following_id = auth.uid()
          ))
        )
    )
  );

-- 2. Update search_itineraries: public + friends (mutual only) + own (all visibility)
CREATE OR REPLACE FUNCTION search_itineraries(
  p_search_query TEXT DEFAULT NULL,
  p_days_count INT DEFAULT NULL,
  p_style_tags TEXT[] DEFAULT NULL,
  p_mode_filter TEXT DEFAULT NULL,
  p_result_limit INT DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  author_id UUID,
  title TEXT,
  destination TEXT,
  days_count INT,
  style_tags TEXT[],
  mode TEXT,
  visibility TEXT,
  forked_from_itinerary_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  author_name TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  WITH escaped AS (
    SELECT CASE
      WHEN p_search_query IS NULL OR p_search_query = '' THEN NULL
      ELSE '%' || replace(replace(replace(p_search_query, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%'
    END AS pattern
  ),
  matching AS (
    SELECT DISTINCT i.id
    FROM itineraries i
    CROSS JOIN escaped e
    WHERE i.forked_from_itinerary_id IS NULL
      AND (
        i.visibility = 'public'
        OR (i.author_id = auth.uid())
        OR (i.visibility = 'friends' AND EXISTS (
          SELECT 1 FROM follows fa, follows fb
          WHERE fa.follower_id = auth.uid() AND fa.following_id = i.author_id
            AND fb.follower_id = i.author_id AND fb.following_id = auth.uid()
        ))
      )
      AND (p_days_count IS NULL OR i.days_count = p_days_count)
      AND (p_mode_filter IS NULL OR i.mode = p_mode_filter)
      AND (p_style_tags IS NULL OR array_length(p_style_tags, 1) IS NULL OR i.style_tags && p_style_tags)
      AND (
        e.pattern IS NULL
        OR i.title ILIKE e.pattern ESCAPE E'\\'
        OR i.destination ILIKE e.pattern ESCAPE E'\\'
        OR EXISTS (
          SELECT 1 FROM itinerary_stops s
          WHERE s.itinerary_id = i.id AND s.name ILIKE e.pattern ESCAPE E'\\'
        )
      )
  )
  SELECT
    i.id,
    i.author_id,
    i.title,
    i.destination,
    i.days_count,
    i.style_tags,
    i.mode,
    i.visibility,
    i.forked_from_itinerary_id,
    i.created_at,
    i.updated_at,
    p.name AS author_name
  FROM itineraries i
  JOIN matching m ON m.id = i.id
  LEFT JOIN profiles p ON p.id = i.author_id
  ORDER BY i.created_at DESC
  LIMIT p_result_limit;
$$;
