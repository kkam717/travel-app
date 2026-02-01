#!/bin/bash
# Run Flutter app with GEOAPIFY_API_KEY from .env (fixes .env not loading on iOS)
set -e

cd "$(dirname "$0")/.."

GEOAPIFY_KEY="${GEOAPIFY_API_KEY:-}"
if [ -z "$GEOAPIFY_KEY" ] && [ -f .env ]; then
  GEOAPIFY_KEY=$(grep -E '^GEOAPIFY_API_KEY=' .env 2>/dev/null | cut -d= -f2- | tr -d '\r' || true)
fi

if [ -n "$GEOAPIFY_KEY" ]; then
  echo "Using GEOAPIFY_API_KEY from .env"
  exec flutter run --dart-define=GEOAPIFY_API_KEY="$GEOAPIFY_KEY" "$@"
else
  echo "GEOAPIFY_API_KEY not found in .env - map will use OSM tiles"
  exec flutter run "$@"
fi
