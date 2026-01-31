# Email Verification Setup Guide

This guide helps fix common issues with Supabase email verification.

## 1. Configure Redirect URLs (Required)

### Option A: Hosted redirect page (recommended – works on mobile & PC)

Deploy the `auth_redirect/` folder to Vercel or Netlify. On **mobile**, users get an "Open app" button. On **PC**, they see "Email verified! Open the app on your phone."

1. Deploy `auth_redirect/` to [Vercel](https://vercel.com) or [Netlify](https://netlify.com) (set Root/Base directory to `auth_redirect`)
2. Add to Supabase **Redirect URLs**:
   ```
   https://your-site.vercel.app/auth_redirect
   travelapp://auth/callback
   travelapp://**
   ```
3. In `.env`: `SUPABASE_AUTH_REDIRECT_URL=https://your-site.vercel.app/auth_redirect`

### Option B: Custom scheme only (mobile only)

If you skip the hosted page, verification links only work on mobile. On PC, `travelapp://` will fail.

1. Add to Supabase **Redirect URLs**:
   ```
   travelapp://auth/callback
   travelapp://**
   ```
2. Do not set `SUPABASE_AUTH_REDIRECT_URL` in `.env`

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

- [ ] Add `travelapp://auth/callback` and `travelapp://**` to Supabase Redirect URLs
- [ ] (Optional) Configure custom SMTP for better deliverability
- [ ] (Optional) Verify your domain with your email provider
