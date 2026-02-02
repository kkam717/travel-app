#!/bin/bash
# Build Flutter web app for deployment
# Web maps use flutter_map (Geoapify/Carto) - no Google Maps script needed
set -e

cd "$(dirname "$0")/.."

echo "Building Flutter web..."
flutter build web --release

echo ""
echo "✓ Web build ready: build/web/"
echo "Deploy the contents of build/web/ to Vercel, Netlify, or any static host."
echo ""
echo "Supabase: Add your deployed URL (e.g. https://your-app.vercel.app) to Redirect URLs."
