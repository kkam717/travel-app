#!/bin/bash
# Build Flutter web app for deployment
# Injects GOOGLE_API_KEY from .env into web/index.html
set -e

cd "$(dirname "$0")/.."

# Load Google API key from env, .env, or android/local.properties
GOOGLE_KEY="${GOOGLE_API_KEY:-}"
if [ -z "$GOOGLE_KEY" ] && [ -f .env ]; then
  GOOGLE_KEY=$(grep -E '^GOOGLE_API_KEY=' .env 2>/dev/null | cut -d= -f2- | tr -d '\r' || true)
fi
if [ -z "$GOOGLE_KEY" ] && [ -f android/local.properties ]; then
  GOOGLE_KEY=$(grep 'GOOGLE_MAPS_API_KEY=' android/local.properties 2>/dev/null | cut -d= -f2- | tr -d '\r' || true)
fi

INDEX_HTML="web/index.html"
BACKUP="${INDEX_HTML}.bak"

# Replace placeholder with actual key
if [ -n "$GOOGLE_KEY" ]; then
  cp "$INDEX_HTML" "$BACKUP"
  sed -i.tmp "s/YOUR_GOOGLE_API_KEY/$GOOGLE_KEY/g" "$INDEX_HTML"
  rm -f "${INDEX_HTML}.tmp"
else
  if [ -n "${CI:-}" ]; then
    echo "ERROR: GOOGLE_API_KEY is not set. Add it to GitHub Secrets (Settings → Secrets → Actions)."
    echo "Maps will not load on web without a valid API key."
    exit 1
  else
    echo "WARNING: GOOGLE_API_KEY not found. Maps will not load on web."
    echo "Add GOOGLE_API_KEY to .env or run: GOOGLE_API_KEY=your-key ./scripts/build_web.sh"
  fi
fi

echo "Building Flutter web..."
flutter build web --release

# Restore original index.html
if [ -n "$GOOGLE_KEY" ] && [ -f "$BACKUP" ]; then
  mv "$BACKUP" "$INDEX_HTML"
fi

echo ""
echo "✓ Web build ready: build/web/"
echo "Deploy the contents of build/web/ to Vercel, Netlify, or any static host."
echo ""
echo "Supabase: Add your deployed URL (e.g. https://your-app.vercel.app) to Redirect URLs."
