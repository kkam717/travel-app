-- Location-based search functions
-- Search trips with stops near a location (using Haversine formula)
CREATE OR REPLACE FUNCTION search_trips_by_location(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50.0,
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
  WITH matching_itineraries AS (
    SELECT DISTINCT i.id
    FROM itineraries i
    INNER JOIN itinerary_stops s ON s.itinerary_id = i.id
    WHERE i.visibility = 'public'
      AND i.forked_from_itinerary_id IS NULL
      AND s.lat IS NOT NULL
      AND s.lng IS NOT NULL
      AND (
        -- Haversine formula: distance in km
        6371 * acos(
          LEAST(1.0,
            cos(radians(p_lat)) *
            cos(radians(s.lat)) *
            cos(radians(s.lng) - radians(p_lng)) +
            sin(radians(p_lat)) *
            sin(radians(s.lat))
          )
        )
      ) <= p_radius_km
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
  JOIN matching_itineraries m ON m.id = i.id
  LEFT JOIN profiles p ON p.id = i.author_id
  ORDER BY i.created_at DESC
  LIMIT p_result_limit;
$$;

-- Search people (profiles) who have authored trips with stops near a location
CREATE OR REPLACE FUNCTION search_people_by_location(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50.0,
  p_result_limit INT DEFAULT 30
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
  WITH matching_authors AS (
    SELECT DISTINCT i.author_id
    FROM itineraries i
    INNER JOIN itinerary_stops s ON s.itinerary_id = i.id
    WHERE i.visibility = 'public'
      AND i.forked_from_itinerary_id IS NULL
      AND s.lat IS NOT NULL
      AND s.lng IS NOT NULL
      AND (
        -- Haversine formula: distance in km
        6371 * acos(
          LEAST(1.0,
            cos(radians(p_lat)) *
            cos(radians(s.lat)) *
            cos(radians(s.lng) - radians(p_lng)) +
            sin(radians(p_lat)) *
            sin(radians(s.lat))
          )
        )
      ) <= p_radius_km
  )
  SELECT
    p.id,
    p.name,
    p.photo_url,
    COUNT(DISTINCT i.id) AS trips_count,
    COUNT(DISTINCT f.follower_id) AS followers_count
  FROM profiles p
  JOIN matching_authors m ON m.author_id = p.id
  LEFT JOIN itineraries i ON i.author_id = p.id AND i.forked_from_itinerary_id IS NULL
  LEFT JOIN follows f ON f.following_id = p.id
  GROUP BY p.id, p.name, p.photo_url
  ORDER BY trips_count DESC, p.name
  LIMIT p_result_limit;
$$;
