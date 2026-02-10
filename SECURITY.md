# Security Checklist for Pushing to GitHub

## Before You Push

### ✅ Secrets Are Gitignored

These files contain secrets and **must not** be committed:

| File | Contains | Status |
|------|----------|--------|
| `.env` | Supabase URL/key, Google API key, DEV_PASSWORD | ✅ In `.gitignore` |
| `android/local.properties` | GOOGLE_MAPS_API_KEY, SDK paths | ✅ In `.gitignore` |
| `ios/Flutter/GoogleMapsKeys.xcconfig` | GOOGLE_MAPS_API_KEY | ✅ In `ios/.gitignore` |

### ✅ No Hardcoded Keys in Tracked Files

- `AndroidManifest.xml` – uses `${GOOGLE_MAPS_API_KEY}` from `local.properties`
- `Info.plist` – uses `$(GOOGLE_MAPS_API_KEY)` from xcconfig
- No API keys in Dart code – keys loaded from `.env` at runtime (see API key handling below)

### Verify Before Pushing

```bash
# Check that .env is ignored
git check-ignore -v .env

# Check for accidental commits of secrets (run before first push)
git log -p --all -S "AIza" -- "*.xml" "*.plist" "*.swift" "*.kt" "*.dart"
```

### If You Already Pushed Secrets

1. **Rotate all keys immediately** in Supabase and Google Cloud Console
2. Remove the keys from git history (e.g. `git filter-branch` or BFG Repo-Cleaner)
3. Force-push (only if no one else has pulled)

---

## API Key Handling (OWASP-aligned)

- **No hardcoded keys:** All API keys (Supabase, Geoapify, GeoNames, LibreTranslate, etc.) are read from environment variables via `flutter_dotenv` (`.env`), never from source code.
- **Client-side:** Only the Supabase **anon** key is used in the app; the **service_role** key must never be included in client builds or `.env` used for app distribution.
- **Rotation:** Rotate keys if they are ever exposed or suspected compromised; update `.env` and redeploy. Document rotation in your runbook.
- **Exposure:** Ensure `.env` is in `.gitignore` and never committed; CI/build pipelines should inject secrets, not commit them.

---

## Rate Limiting

- **Client-side:** `lib/core/rate_limiter.dart` enforces per-action limits (e.g. auth, mutations, search) to reduce abuse and give users clear 429-style feedback (`rate_limit_try_again`).
- **Backend:** Supabase/PostgREST do not enforce per-endpoint rate limits by default. For production, consider Supabase Edge Functions or a reverse proxy (e.g. Kong, nginx) to add IP/user-based rate limiting on public endpoints.

---

## Input Validation and Sanitization

- **Schema-based:** `lib/core/input_validation.dart` defines allowed fields and types for profile updates, itineraries, stops, search, and auth. Unexpected fields are rejected (OWASP: allowlist).
- **Checks:** Type checks, length limits (`maxTitleLength`, `maxSearchQueryLength`, etc.), and sanitization (`sanitizeString`, `sanitizeUrl`) are applied before sending data to Supabase.
- **User-facing errors:** Invalid input throws `ValidationException`; callers should catch it and show a clear message (e.g. validation error or generic failure).

---

## Supabase Anon Key

The Supabase **anon** key is designed for client-side use and is protected by Row Level Security (RLS). It's acceptable in `.env` as long as `.env` is never committed. Never expose the **service_role** key.

## Developer Sign-In

`DEV_EMAIL` and `DEV_PASSWORD` in `.env` are for local development only. Never commit them. Use a test account, not your real credentials.
