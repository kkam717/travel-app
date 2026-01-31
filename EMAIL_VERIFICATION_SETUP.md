# Email Verification Setup Guide

This guide helps fix two common issues with Supabase email verification:

1. **Verification links showing about:blank** – Browsers block direct redirects to custom URL schemes
2. **Emails going to spam** – Poor deliverability with Supabase's default email

## 1. Fix about:blank (Required)

When the verification link redirects directly to `travelapp://`, many browsers block it and show about:blank. The fix is to use a **hosted redirect page** that Supabase redirects to first; the page then shows a "Tap to open app" button that works reliably.

### Step 1: Deploy the auth redirect page

**Vercel:**
1. Go to [Vercel](https://vercel.com) and sign in
2. Create a new project → Import your Travel App repo
3. Before deploying, click **Edit** next to "Root Directory"
4. **Type** `auth_redirect` in the field (it may not appear in a dropdown—typing works)
5. Set Framework Preset to **Other** (or leave as auto)
6. Deploy. You'll get a URL like `https://travel-app-auth-xxx.vercel.app`

**Netlify (alternative):** Create a new site from the repo, set Base directory to `auth_redirect`, deploy.

### Step 2: Configure Supabase

1. Open your [Supabase Dashboard](https://supabase.com/dashboard) → your project
2. Go to **Authentication** → **URL Configuration**
3. Under **Redirect URLs**, add:
   ```
   https://your-deployed-url.vercel.app
   travelapp://auth/callback
   travelapp://**
   ```
   (Replace with your actual Vercel/Netlify URL)
4. Save changes

### Step 3: Add the redirect URL to your app

In your `.env` file, add:

```
SUPABASE_AUTH_REDIRECT_URL=https://your-deployed-url.vercel.app
```

(Use the same URL you deployed in Step 1.)

### How it works

1. User signs up → receives verification email
2. User clicks link → browser goes to Supabase → Supabase redirects to your hosted page with auth tokens in the URL
3. Your page shows "Email verified! Tap to open the app" with a button
4. User taps the button → app opens and completes sign-in

---

## 2. Fix Emails Going to Spam (Recommended for Production)

Supabase's default email has limited deliverability. Using a custom SMTP provider (Resend, SendGrid, etc.) greatly improves inbox placement.

### Option A: Resend (Recommended)

1. Create an account at [resend.com](https://resend.com)
2. Verify your domain (add the DNS records they provide)
3. Create an API key
4. In Supabase Dashboard → **Project Settings** → **Authentication** → **SMTP Settings**:
   - Enable **Custom SMTP**
   - **Host:** `smtp.resend.com`
   - **Port:** `465`
   - **Username:** `resend`
   - **Password:** Your Resend API key
   - **Sender email:** `noreply@yourdomain.com` (must be from your verified domain)
   - **Sender name:** `Travel App` (or your app name)

### Option B: SendGrid

1. Create an account at [sendgrid.com](https://sendgrid.com)
2. Verify your domain
3. Create an API key with "Mail Send" permission
4. In Supabase SMTP Settings:
   - **Host:** `smtp.sendgrid.net`
   - **Port:** `587`
   - **Username:** `apikey`
   - **Password:** Your SendGrid API key
   - **Sender email:** From your verified domain

### Option C: Other SMTP Providers

Supabase works with any SMTP-compatible provider (AWS SES, Postmark, Brevo, etc.). Use your provider's SMTP host, port, and credentials.

---

## Summary Checklist

- [ ] Deploy `auth_redirect/` folder to Vercel or Netlify
- [ ] Add your HTTPS redirect URL and `travelapp://auth/callback`, `travelapp://**` to Supabase Redirect URLs
- [ ] Add `SUPABASE_AUTH_REDIRECT_URL` to your `.env` file
- [ ] (Optional) Configure custom SMTP for better deliverability
- [ ] (Optional) Verify your domain with your email provider
