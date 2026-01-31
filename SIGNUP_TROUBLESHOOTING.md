# Signup Troubleshooting Guide

If signup says "check email" but no email arrives and the user doesn't appear in Supabase:

## Debug output (flutter run)

When signup works, you'll see:
```
SignUp: redirectTo=https://...
SignUp response: user=<uuid>, session=false
```
- **user=xxx** means the user WAS created in Supabase
- **session=false** is normal when email confirmation is required

## 1. Check Authentication → Users (not Profiles)

Users appear in **Authentication → Users** first. The `profiles` table is populated by a trigger when a user is created. Check **Authentication → Users** in your Supabase project `jxhddqkutnmstalcnutr`.

## 2. Check Auth Logs

Supabase Dashboard → **Authentication** → **Logs**

Look for failed signup attempts. Common errors:
- **"Invalid redirect URL"** – Add `https://travel-app-rpp7.vercel.app/auth_redirect` to Redirect URLs
- **"Signup disabled"** – Enable "Allow new users to sign up" in Providers → Email
- **"Email not allowed"** – Default SMTP only sends to team members (see #4)

## 3. Verify Redirect URL

Supabase Dashboard → **Authentication** → **URL Configuration** → **Redirect URLs**

Must include exactly:
```
https://travel-app-rpp7.vercel.app/auth_redirect
travelapp://auth/callback
travelapp://**
```

If the redirect URL is wrong, signup can fail silently or return an error.

## 4. Fix "No Email" – Pre-authorized Addresses

Supabase's default email **only sends to team member addresses**. Add your test email:

1. Supabase Dashboard → **Organization** (top left) → **Team**
2. **Invite** the email address you're signing up with
3. Accept the invite

Or set up **Custom SMTP** (Resend, SendGrid) to send to any address:
- Project Settings → Authentication → SMTP Settings

## 5. Test Without Redirect URL

Temporarily remove `SUPABASE_AUTH_REDIRECT_URL` from `.env` (or comment it out). The app will use `travelapp://auth/callback` instead. If signup works, the issue may be with the Vercel URL.

## 6. Run with Debug Logging

```bash
flutter run
```

Try signup and watch the terminal for:
- `SignUp: redirectTo=...` – confirms which URL is being used
- `SignUp response: user=xxx` – confirms a user was created (xxx = user id)
- Any `Auth error:` or `Signup error:` messages

## 7. Confirm Same Project

Your `.env` uses `jxhddqkutnmstalcnutr.supabase.co`. Make sure you're looking at that project in the Supabase Dashboard.
