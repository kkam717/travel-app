-- Add places_summary to search_people_by_location so the app can show
-- "Country - City1 • City2 • City3" for each person when searching by place.
-- Must DROP first because PostgreSQL does not allow changing return type with CREATE OR REPLACE.
DROP FUNCTION IF EXISTS search_people_by_location(double precision, double precision, double precision, integer);

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
  followers_count BIGINT,
  places_summary TEXT
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
  ),
  -- Only include destination-level stops (cities/places), not venues, experiences, or POI names.
  -- Require stop_type = 'location' or category = 'location' so we never include Café Central, hotels, etc.
  stops_in_radius AS (
    SELECT
      i.author_id,
      COALESCE(TRIM(pl.country), '') AS country,
      CASE
        WHEN pl.id IS NOT NULL AND NULLIF(TRIM(pl.city), '') IS NOT NULL THEN TRIM(pl.city)
        ELSE TRIM(s.name)
      END AS place_name
    FROM itineraries i
    INNER JOIN itinerary_stops s ON s.itinerary_id = i.id
    LEFT JOIN places pl ON pl.id = s.place_id
    WHERE i.visibility = 'public'
      AND i.forked_from_itinerary_id IS NULL
      AND s.lat IS NOT NULL
      AND s.lng IS NOT NULL
      AND (s.stop_type = 'location' OR s.category = 'location')
      AND (
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
  ),
  distinct_places AS (
    SELECT DISTINCT author_id, country, place_name
    FROM stops_in_radius
    WHERE place_name IS NOT NULL AND TRIM(place_name) <> ''
  ),
  author_places_grouped AS (
    SELECT
      author_id,
      country,
      string_agg(place_name, ' • ' ORDER BY place_name) AS places_text
    FROM distinct_places
    GROUP BY author_id, country
  ),
  author_summary AS (
    SELECT
      author_id,
      string_agg(
        CASE WHEN country <> '' THEN country || ' - ' || places_text ELSE places_text END,
        ' • '
        ORDER BY country, places_text
      ) AS places_summary
    FROM author_places_grouped
    GROUP BY author_id
  )
  SELECT
    p.id,
    p.name,
    p.photo_url,
    COUNT(DISTINCT i.id) AS trips_count,
    COUNT(DISTINCT f.follower_id) AS followers_count,
    COALESCE(a.places_summary, '') AS places_summary
  FROM profiles p
  JOIN matching_authors m ON m.author_id = p.id
  LEFT JOIN author_summary a ON a.author_id = p.id
  LEFT JOIN itineraries i ON i.author_id = p.id AND i.forked_from_itinerary_id IS NULL
  LEFT JOIN follows f ON f.following_id = p.id
  GROUP BY p.id, p.name, p.photo_url, a.places_summary
  ORDER BY trips_count DESC, p.name
  LIMIT p_result_limit;
$$;
