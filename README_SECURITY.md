# Security Hardening Report

This document summarizes the security hardening pass (RLS, constraints, storage, idempotency, logging) and provides a standing **Security Invariants** section for future changes.

---

## 1. What Was Changed

### A) Supabase authorization / RLS

- **Inventory:** Tables used by the app: `profiles`, `places`, `itineraries`, `itinerary_stops`, `bookmarks`, `follows`, `itinerary_likes`, `user_past_cities`, `user_top_spots`, and `storage.objects` (avatars bucket).
- **RLS:** All these tables already had RLS enabled. No new tables were added without RLS.
- **Policies (verified):**
  - **itineraries:** SELECT only when visibility allows (public, or private/friends with owner/mutual-friend rules); INSERT/UPDATE/DELETE require `auth.uid() = author_id`. Client-sent `author_id` is never trusted for permission—RLS enforces ownership.
  - **itinerary_stops:** SELECT when parent itinerary is visible; INSERT/UPDATE/DELETE only when parent `author_id = auth.uid()`.
  - **bookmarks / itinerary_likes:** INSERT/DELETE only with `auth.uid() = user_id`. Like and bookmark counts are **not** stored on itineraries; they are computed via RPCs (`get_like_counts`, `get_bookmark_counts`), so clients cannot modify counts directly.
  - **follows:** INSERT/UPDATE/DELETE only with `auth.uid() = follower_id`; uniqueness `(follower_id, following_id)` and `follower_id != following_id` enforced.
  - **profiles:** UPDATE/INSERT only `auth.uid() = id`.
  - **user_past_cities / user_top_spots:** CRUD only `auth.uid() = user_id`.
  - **places:** SELECT for authenticated; INSERT currently allowed for any authenticated user (`WITH CHECK (true)`). This is intentional for crowdsourced place data; lock down further if required.
- **Migration 033:** Added CHECK constraints (see below) and a storage DELETE policy for avatars.

### B) Database integrity (migration `033_security_hardening_rls_constraints.sql`)

- **itineraries:** `days_count` 1–365, `cost_per_person >= 0` (or NULL), `duration_month` 1–12 (or NULL), `duration_year` 1900–2100 (or NULL).
- **itinerary_stops:** `lat` -90–90, `lng` -180–180, `position >= 0`, `day` 1–365 (or NULL).
- **Uniqueness (already in place):** `(user_id, itinerary_id)` for bookmarks and likes; `(follower_id, following_id)` for follows; `(user_id, city_name)` for user_past_cities.
- **Storage:** Policy "Users can delete own avatar" so users can delete only their own object in the `avatars` bucket.

### C) Supabase Storage

- **Buckets:** Only `avatars` is used (public read for profile photos). Write/update/delete restricted to own path via RLS (`(storage.foldername(name))[1] = auth.uid()::text`).
- **App (SupabaseService):** Avatar upload now enforces max file size (5MB), allowlisted extensions (jpg, jpeg, png, gif, webp), and filename/extension sanitization (no path traversal; unknown extension falls back to `jpg`).

### D) Service role key

- **Search:** No `service_role` or server-bypass key in Flutter/client code, `.env.example`, or logs. Only the anon key is used in the app. Confirmed in SECURITY.md and rules.

### E) Abuse prevention

- **Idempotency:** `addBookmark` and `addLike` treat Postgres unique_violation (23505) as success (already bookmarked/liked). `followUser` already did the same. Repeated taps do not create duplicates and do not surface errors.
- **Bot mitigations:** No Cloudflare Turnstile or equivalent added in this pass; consider for signup/contact forms if needed later.

### F) Logging hygiene

- **Analytics.redactForLog:** Added in `lib/core/analytics.dart`. Redacts email-like substrings and bearer/token-like segments from strings.
- **Usage:** All `Analytics.logEvent(..., {'error': ...})` in `SupabaseService` now pass the error string through `Analytics.redactForLog(...)` so that when analytics/crash reporting are enabled, tokens and PII are not logged.

---

## 2. Checklist

| Item | Status |
|------|--------|
| RLS enabled on all app tables | Done (was already; verified) |
| Deny-by-default policies (no broad `USING (true)` for writes) | Done |
| SELECT policies match app (public vs private/friends) | Done |
| Ownership checks use `auth.uid()` only | Done |
| Like/bookmark counts not writable by client | Done (RPC-only) |
| Uniqueness + CHECK constraints (likes, bookmarks, follows, itineraries, stops) | Done (migration 033) |
| Storage: RLS + delete own avatar only | Done |
| Avatar: file size/type and filename sanitization | Done (app) |
| No service_role in client | Verified |
| Idempotency for like/bookmark/follow | Done |
| Error logs redacted (PII/tokens) | Done |

---

## 3. Security Invariants (standing rule for future edits)

- **New tables:** Must have RLS enabled and explicit policies. No table used by the app should be accessible without a policy that restricts rows by `auth.uid()` or equivalent.
- **No service_role in client:** The Flutter app must never use the Supabase service_role key. Privileged operations belong in Edge Functions or backend services.
- **Public reads must be explicit and minimal:** Any policy that allows SELECT for “everyone” (e.g. public itineraries) must be scoped (e.g. `visibility = 'public'`) and not broad `USING (true)` for sensitive data.
- **Storage:** Buckets must be private by default. If a bucket is public read (e.g. avatars), write/update/delete must be restricted to the owning user (path or metadata). Enforce file size and type at upload (client and optionally server/edge).
- **Counts and sensitive fields:** Do not store like_count/bookmark_count (or similar) on tables that clients can UPDATE. Use RPCs or triggers to compute counts.
- **Logging:** When logging errors or analytics, redact tokens, auth headers, and PII (e.g. use `Analytics.redactForLog` for error strings). Ensure crash reporting does not capture secrets.

---

## 4. Files Touched

- **New:** `supabase/migrations/033_security_hardening_rls_constraints.sql`, `README_SECURITY.md`.
- **Updated:** `.cursor/rules/security-compliance.mdc` (added Security Invariants section).
- **Modified:** `lib/services/supabase_service.dart` (avatar limits/sanitization, idempotency for bookmark/like, redacted error logging), `lib/core/analytics.dart` (redactForLog).

---

## 5. How to Apply

1. Run migrations: `supabase db push` (or your usual migration path).
2. No code migration required; app behavior is unchanged except: duplicate bookmark/like is now a no-op, oversized or disallowed avatar upload fails with validation error, and error analytics payloads are redacted.
