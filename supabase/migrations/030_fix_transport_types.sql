-- Fix unsupported transport types in transport_transitions JSONB
-- Supported types: plane, train, car, bus, boat, walk, other, unknown
-- Also accepts: ferry (maps to boat)

-- Update trips with unsupported transport types
-- Maps: metro/tram -> train, helicopter -> plane, ferry -> boat
UPDATE itineraries
SET transport_transitions = (
  SELECT jsonb_agg(
    CASE
      -- Map unsupported types to supported ones
      WHEN elem->>'type' = 'metro' THEN 
        jsonb_build_object(
          'type', 'train', 
          'description', COALESCE(elem->>'description', 'Metro')
        )
      WHEN elem->>'type' = 'tram' THEN 
        jsonb_build_object(
          'type', 'train', 
          'description', COALESCE(elem->>'description', 'Tram')
        )
      WHEN elem->>'type' = 'helicopter' THEN 
        jsonb_build_object(
          'type', 'plane', 
          'description', COALESCE(elem->>'description', 'Helicopter')
        )
      -- ferry is already supported (maps to boat), but ensure it's stored as 'boat'
      WHEN elem->>'type' = 'ferry' THEN 
        jsonb_build_object(
          'type', 'boat', 
          'description', COALESCE(elem->>'description', 'Ferry')
        )
      -- Keep supported types as-is
      ELSE elem
    END
  )
  FROM jsonb_array_elements(transport_transitions) AS elem
)
WHERE transport_transitions IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(transport_transitions) AS elem
    WHERE elem->>'type' IN ('metro', 'tram', 'helicopter')
  );
