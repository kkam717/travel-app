# Travel App: Deployment & Running Costs Guide

This document consolidates deployment fees, beta vs. full launch workflows, and incremental running costs.

---

## 1. One-Off Fees When Deploying

### One-off fees

| Item | Cost | Notes |
|------|------|-------|
| **Google Play Developer** | **$25** | One-time registration to publish on the Play Store |
| **Apple Developer Program** | **$99/year** | Required for App Store distribution (annual, not one-off) |

### Usually free

- **Supabase** – No setup fee; free tier available
- **Geoapify** – No setup fee; pay-as-you-go or subscription
- **Vercel** (web) – No setup fee; free tier for hobby projects
- **Domain** – Optional; ~$10–15/year if you want a custom domain
- **Code signing** – Free (Apple via dev program; Android keystore is free)
- **SSL/HTTPS** – Free via Vercel/Supabase/Let's Encrypt

### Summary

- **Android only:** ~**$25** one-off (Google Play registration)
- **iOS only:** **$99** for the first year (Apple Developer Program)
- **Both platforms:** ~**$124** in the first year
- **Web only:** **$0** (e.g. Vercel free tier)

---

## 2. Beta Release Costs

### $0 beta options

| Platform | Method | Cost |
|----------|--------|------|
| **Web** | Deploy to Vercel/Netlify, share URL | **$0** |
| **Android** | Build APK → share via Drive/Dropbox/link | **$0** |

### Beta options that cost money

| Platform | Method | Cost |
|----------|--------|------|
| **iOS (TestFlight)** | Apple Developer Program | **$99/year** |
| **Android (Play Store)** | Internal testing track | **$25** one-time |

### Summary

- **Web + Android beta (no stores):** **$0**
- **iOS beta (TestFlight):** **$99/year**
- **Android beta via Play Store:** **$25** one-time

---

## 3. Beta vs. Full Launch Workflow

### iOS: TestFlight (beta) → App Store (full)

| Phase | What happens | Who can install |
|-------|--------------|------------------|
| **Beta (TestFlight)** | Upload builds to TestFlight. Add internal (up to 100) or external testers. Optional Beta App Review for external testers. | Only invited testers via email link |
| **Full launch** | Submit the same app for App Store Review. Add store listing, screenshots, description, etc. | Anyone can search and download |

**Flow:** Same app in App Store Connect. You use TestFlight first, then submit a build for App Store Review when ready. No separate "beta app" vs. "production app" – it's one app graduating from TestFlight to the store.

**Note:** TestFlight builds expire after 90 days; you upload new builds as needed.

### Android: Testing tracks → Production

| Phase | What happens | Who can install |
|-------|--------------|------------------|
| **Beta (Internal)** | Upload to Internal testing. Add up to 100 testers by email. | Only those testers |
| **Beta (Closed)** | Upload to Closed testing. Share an opt-in link. | Anyone with the link who opts in |
| **Beta (Open)** | Upload to Open testing. Public opt-in page. | Anyone who joins the program |
| **Full launch** | Promote a build from a testing track to **Production**. Complete store listing, content rating, privacy policy. | Anyone can search and download |

**Flow:** One app in Play Console. You put builds in Internal → Closed → Open testing first, then promote a build to Production when ready. The app only appears in Play Store search after it's in Production.

### Differences between beta and full launch

| | Beta | Full launch |
|---|------|-------------|
| **Visibility** | Not in store search; invite/link only | Searchable in App Store / Play Store |
| **Audience** | Limited (testers) | Public |
| **Review** | iOS: Beta App Review (or none for internal). Android: usually none for internal | Full store review (both platforms) |
| **Store listing** | Minimal or none | Required: screenshots, description, privacy policy, etc. |
| **Updates** | New builds uploaded to TestFlight / testing tracks | New versions submitted for review |

### Typical sequence

1. **Beta:** Upload builds to TestFlight (iOS) and Internal/Closed testing (Android). Invite testers, collect feedback, fix bugs.
2. **Prepare for full launch:** Add store listing, screenshots, privacy policy, content rating.
3. **Full launch:** Submit for App Store Review (iOS) and promote to Production (Android).
4. **Ongoing:** New versions go through the same review process for each release.

Same app, same codebase; beta is a pre-release phase before making it publicly available in the stores.

---

## 4. Incremental Running Costs by User Base

Monthly costs as MAU increases. Assumes ~62.5 Geoapify credits per MAU (static maps + tiles). Photon, Nominatim, Carto, Natural Earth remain $0 at all scales.

| MAU | Supabase | Geoapify | Geoapify credits/day | Total/month |
|-----|----------|----------|----------------------|-------------|
| **1k** | $0 (Free) or $25 (Pro) | $0 (Free) | ~2k | **$0–25** |
| **2.5k** | $25 (Pro) | $59 (API 10) | ~5k | **$84** |
| **5k** | $25 | $59 (API 10) | ~10k | **$84** |
| **7.5k** | $25 | $109 (API 25) | ~16k | **$134** |
| **10k** | $25 | $109 (API 25) | ~21k | **$134** |
| **25k** | $25 | $179 (API 50) | ~52k | **$204** |
| **50k** | $25 | $299 (API 100) | ~104k | **$324** |
| **100k** | $25 | $609 (API 250) | ~208k | **$634** |
| **150k** | $187 | $860+ (Custom) | ~312k | **~$1,050** |
| **250k** | $512 | $860+ (Custom) | ~520k | **~$1,400** |
| **500k** | $1,300 | Custom | ~1M/day | **~$2,000+** |
| **1M** | $3,025 | Custom | ~2M/day | **~$4,000+** |

### Notes

- **Supabase Free:** 50k MAU, 500MB DB, 5GB egress. Fine for early beta; Pro recommended for production.
- **Supabase Pro:** 100k MAU included; beyond that: **$0.00325 per MAU**.
- **Geoapify Free:** 3k credits/day (~90k/month). Covers ~1.5k MAU.
- **Geoapify tiers:** API 10 (10k/day), API 25 (25k/day), API 50 (50k/day), API 100 (100k/day), API 250 (250k/day), Custom (contact).

---

*Generated for Travel App. Supabase, Geoapify, Photon, Nominatim, Carto.*
