# Trip test data review (24 itineraries cccc0000-...-000001 to 000024)

## Schema and IDs
- **Itinerary IDs**: Format `cccc0000-0000-0000-0000-000000000001` … `000000000024` — correct.
- **Columns**: Match current schema (itineraries + itinerary_stops with day, position, name, stop_type, category, external_url, lat, lng, rating). All good.

## Transport types
- Supported in app and migration 030: `plane`, `train`, `car`, `bus`, `boat`, `walk`, `other`, `unknown`.
- `ferry` is accepted by the app (maps to boat); migration 030 and 031 normalize it to `boat` in DB.
- Your data uses `train`, `car`, `plane`, `bus`, `ferry` — all valid. Migration 031 normalizes `ferry` → `boat`.

## Transport transition count (main fix)
Rule: **`transport_transitions` length must equal `days_count - 1`** (one entry per segment between consecutive days).  
The timeline uses index `i` for the segment between day `i` and day `i+1`. If the array is shorter, later segments show as "unknown".

| Itinerary | Days | Transitions in data | Expected | Status |
|-----------|------|---------------------|----------|--------|
| 000001 Paris | 4 | 0 | 3 | OK (empty) |
| 000002 Amsterdam→Rotterdam | 5 | 1 | 4 | **Padded** |
| 000003 Edinburgh | 3 | 0 | 2 | OK |
| 000004 Vienna | 5 | 0 | 4 | OK |
| 000005 Tokyo | 6 | 0 | 5 | OK |
| 000006 Kyoto+Osaka | 5 | 2 | 4 | **Padded** |
| 000007 Tokyo→Hakone | 4 | 2 | 3 | **Padded** |
| 000008 Seoul | 3 | 0 | 2 | OK |
| 000009 Milan→Como→Bellagio | 6 | 2 | 5 | **Padded** (incl. ferry→boat) |
| 000010 Paris | 4 | 0 | 3 | OK |
| 000011 Rome | 3 | 0 | 2 | OK |
| 000012 Florence→Siena | 5 | 2 | 4 | **Padded** |
| 000013 Mexico City | 5 | 0 | 4 | OK |
| 000014 Peru | 6 | 3 | 5 | **Padded** |
| 000015 NYC | 3 | 0 | 2 | OK |
| 000016 Iceland | 7 | 2 | 6 | **Padded** |
| 000017 Norway | 6 | 2 | 5 | **Padded** (incl. ferry→boat) |
| 000018 Copenhagen→Malmö | 4 | 1 | 3 | **Padded** |
| 000019 Bornholm | 3 | 2 | 2 | OK (length already 2) |
| 000020 Finland | 4 | 1 | 3 | **Padded** (ferry→boat) |
| 000021 Lisbon | 5 | 0 | 4 | OK |
| 000022 Andalucía | 7 | 2 | 6 | **Padded** |
| 000023 Marrakech | 4 | 0 | 3 | OK |
| 000024 Costa Brava | 5 | 2 | 4 | **Padded** |

Migration **031_check_and_fix_test_trips_transport.sql**:
1. Normalizes `ferry` → `boat` for these test itineraries.
2. Pads `transport_transitions` to length `days_count - 1` with `{"type":"unknown"}` (existing entries kept in order).

## Optional data note
- **000006 (Kyoto + Osaka)**: One description says "Shinkansen Tokyo → Kyoto". The first stop is Kyoto (day 1), so that text is a bit misleading; consider changing to e.g. "Train to Kyoto" or "Shinkansen to Kyoto" if you want it to match the actual route.

## Summary
- Data is valid and consistent with the schema.
- Run migration **031** after inserting the 24 trips so transport segments align with the timeline and map (no wrong/missing segment types). Ferry is normalized to boat.
