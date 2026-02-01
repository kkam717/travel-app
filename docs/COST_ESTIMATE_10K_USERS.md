# Running Cost Estimate: 10,000 Users (MAU)

Estimated monthly costs for the Travel App at **10,000 monthly active users (MAU)**. Assumptions and usage patterns are based on the current architecture (Supabase, Geoapify, Photon, Nominatim, Carto).

---

## Summary

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| **Supabase** | $25 | Pro plan (100k MAU included) |
| **Geoapify** | $59–109 | API 10 or API 25 (static maps + tiles) |
| **Photon** | $0 | Free place search (OSM) |
| **Nominatim** | $0 | Free geocoding (rate-limited) |
| **Carto** | $0 | Free map tiles |
| **Natural Earth** | $0 | Static GeoJSON |
| **Total** | **~$84–134/month** | |

---

## 1. Supabase

**Plan:** Pro ($25/month)

- **MAU:** 10k users within 100k included
- **Database:** 8 GB included (profiles, itineraries, stops, follows, bookmarks)
- **Egress:** 250 GB included
- **Storage:** 100 GB for profile photos
- **Auth:** Unlimited

**Estimate:** **$25/month** (base Pro; no overages expected at 10k users)

---

## 2. Geoapify

**Usage:**
- **Static map images** (feed cards): ~1.5 credits each (1 base + ~0.5 for tiles). Assumption: 25 unique static maps per user per month → 250k requests → **~375k credits/month**.
- **Map tiles** (itinerary map): 0.25 credits/tile. ~14 tiles per map view; assume ~8 itinerary map views per user per month (with caching) → ~100 tiles/user → **1M tiles** → **250k credits/month**.

**Total Geoapify:** ~375k (static) + 250k (tiles) = **~625k credits/month** ≈ **20.8k credits/day**

**Plans:**
- Free: 3k credits/day (90k/month) — too low
- API 10: 10k credits/day ($59) — too low
- **API 25: 25k credits/day ($109)** — fits

**Estimate:** **$109/month** (API 25)

*If usage is lighter (e.g. 200k static maps, 200k tiles): ~400k credits/month ≈ 13k/day → API 10 ($59) may suffice.*

---

## 3. Photon & Nominatim (free)

**Place search:** Photon (photon.komoot.io) — free, no API key.  
**Geocoding:** Nominatim (nominatim.openstreetmap.org) — free, 1 req/sec limit.  
**Map links:** OpenStreetMap URLs — free.

**Estimate:** **$0**

---

## 4. Carto

- **Countries map** and **itinerary map fallback** (no Geoapify key)
- Free for reasonable usage

**Estimate:** **$0**

---

## 5. Natural Earth

- GeoJSON for country polygons (static, bundled or cached)

**Estimate:** **$0**

---

## Total Monthly Estimate

| Scenario | Supabase | Geoapify | Total |
|----------|----------|----------|-------|
| **Conservative** | $25 | $59 | **~$84** |
| **Moderate** | $25 | $109 | **~$134** |

**Recommended planning range:** **~$85–135/month** at 10k MAU.

---

## Cost Optimization Tips

1. **Geoapify:** Use API 10 ($59) if usage stays under ~300k credits/month; monitor and upgrade to API 25 if needed.
2. **Nominatim:** Respect 1 req/sec limit; add delays between geocode calls.
3. **Caching:** Cache static map URLs and geocode results where possible.
