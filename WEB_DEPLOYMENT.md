# Deploy Travel App to Web

Build and deploy the Travel App as a web app (works on iOS Safari, Android Chrome, desktop).

## Quick Start

### Option A: GitHub Actions (recommended)

1. **Connect your repo to Vercel** at [vercel.com/new](https://vercel.com/new)
2. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `VERCEL_ORG_ID` – from [Vercel Project Settings → General](https://vercel.com/docs/projects/overview#project-id)
   - `VERCEL_PROJECT_ID` – from [Vercel Project Settings → General](https://vercel.com/docs/projects/overview#project-id)
   - `VERCEL_TOKEN` – create at [vercel.com/account/tokens](https://vercel.com/account/tokens)
   - `GOOGLE_API_KEY` – your Google Maps API key

   To get org/project IDs: run `vercel link` locally, then check `.vercel/project.json`
3. **Push to `main`** – the workflow deploys automatically

### Option B: Manual build & deploy

1. **Build the web app:**
   ```bash
   ./scripts/build_web.sh
   ```
   This injects your Google API key from `.env` (or `GOOGLE_API_KEY` env var) and outputs to `build/web/`.

2. **Deploy** the `build/web/` folder:
   - **Vercel**: `cd build/web && vercel --prod`
   - **Netlify**: Drag `build/web` to [app.netlify.com/drop](https://app.netlify.com/drop)
   - **GitHub Pages**: Push `build/web` to a `gh-pages` branch

## Supabase Configuration

Add your deployed web URL to **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**:

```
https://your-app.vercel.app
https://your-app.netlify.app
```

(Use your actual deployed URL.)

## Google Maps API Key

The build script reads `GOOGLE_API_KEY` from `.env` (or `GOOGLE_MAPS_API_KEY` from `android/local.properties`) and injects it into `web/index.html` for the Maps JavaScript API.

Enable these APIs in [Google Cloud Console](https://console.cloud.google.com/apis/library):
- **Maps JavaScript API** (required for web maps)
- Places API

### Maps not loading ("This page didn't load Google Maps correctly")

1. **Add `GOOGLE_API_KEY` to GitHub Secrets** (Settings → Secrets and variables → Actions) – required for CI deploys
2. **Enable Maps JavaScript API** in [Google Cloud Console](https://console.cloud.google.com/apis/library)
3. **API key restrictions**: If using HTTP referrer, add your deployed URL (e.g. `https://*.vercel.app/*`)
4. **Redeploy** after adding the secret – the build injects the key into the HTML

## Add to Home Screen (iOS)

Users can open the web app in Safari and tap **Share → Add to Home Screen** for an app-like experience.
