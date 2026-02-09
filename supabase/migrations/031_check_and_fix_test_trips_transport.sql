-- ============================================================
-- Fix transport_transitions for test itineraries (cccc0000-...)
-- Rule: transport_transitions should have length = days_count - 1
-- (one entry per segment between consecutive days).
-- Pad with {"type":"unknown"} where missing.
-- Normalize "ferry" -> "boat" for consistency with 030_fix_transport_types.
-- ============================================================

-- 1) Normalize ferry -> boat in transport_transitions (same as migration 030)
UPDATE itineraries
SET transport_transitions = (
  SELECT jsonb_agg(
    CASE
      WHEN elem->>'type' = 'ferry' THEN
        jsonb_build_object(
          'type', 'boat',
          'description', COALESCE(elem->>'description', 'Ferry')
        )
      ELSE elem
    END
  )
  FROM jsonb_array_elements(transport_transitions) AS elem
)
WHERE id::text LIKE 'cccc0000-0000-0000-0000-%'
  AND transport_transitions IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(transport_transitions) AS elem
    WHERE elem->>'type' = 'ferry'
  );

-- 2) Pad transport_transitions to length (days_count - 1) with {"type":"unknown"}
--    Only for test itinerary IDs cccc0000-... (keeps existing entries, pads at end)
UPDATE itineraries i
SET transport_transitions = (
  SELECT jsonb_agg(
    COALESCE(
      (i.transport_transitions->(idx - 1)),
      '{"type":"unknown"}'::jsonb
    )
    ORDER BY idx
  )
  FROM generate_series(1, i.days_count - 1) AS idx
)
WHERE i.id::text LIKE 'cccc0000-0000-0000-0000-%'
  AND i.days_count >= 2
  AND (
    i.transport_transitions IS NULL
    OR jsonb_array_length(i.transport_transitions) < (i.days_count - 1)
  );
