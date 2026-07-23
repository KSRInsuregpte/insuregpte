# Protected Registration Deployment

**Version:** 1.1
**Date:** 2026-07-23
**Status:** Temporary email-only activation approved

## Purpose

This release protects public registration while preserving Supabase Auth as the
only identity and OTP authority. It requires:

- complete registration data;
- at least one active subject;
- Cloudflare Turnstile CAPTCHA;
- email confirmation by six-digit OTP;
- required normalized unique mobile capture;
- mobile SMS OTP deferred until a production provider plan is approved;
- a recorded registration/referral source;
- an active profile before protected table or RPC access;
- the existing one-active-page session policy.

OTP values, passwords, SMS secrets, and CAPTCHA secrets are never stored in
application tables or browser source.

## Deployment Safety Rule

Keep **Allow new users to sign up** switched off until every step in this guide
has passed. Keep **Allow anonymous sign-ins** switched off permanently.

## Step 1 — Preserve and Audit the Suspicious Registration

1. Run `sql/audit-registration-security.sql` in the Supabase SQL Editor.
2. Export the single result table and retain it with the incident record.
3. Confirm whether user
   `a7127f24-7a13-4b8e-b1f0-235ca25ff0b3` has:
   - an email confirmation;
   - any Auth session;
   - any sign-in time;
   - any completed profile data.
4. If it remains unverified and has no legitimate activity, use
   **Authentication → Users** to ban or delete it.
5. Do not delete the user directly with SQL. Supabase Auth must control Auth
   user deletion and related cleanup.

IP address `157.230.182.115` may be recorded as an incident indicator, but IP
blocking must not be treated as the primary defence because automated sources
can change addresses.

## Step 2 — Complete the Existing Session Prerequisites

Apply and verify these existing migrations first if they are not already live:

1. `supabase/migrations/20260720090000_add_active_client_lease.sql`
2. Deploy the current `index.html`, `dashboard.html`, `test.html`, and
   `js/session-control.js` session-control frontend.
3. `supabase/migrations/20260720100000_require_active_client_lease.sql`
4. `TESTING/sql/active-client-lease-verification.sql`

The protected-registration migration intentionally stops if strict
active-client lease enforcement is not present.

## Step 3 — Create Cloudflare Turnstile Keys

1. Open Cloudflare Turnstile and create one widget.
2. Add these production hostnames:
   - `insuregpte.in`
   - `www.insuregpte.in`
3. Add the staging hostname separately when staging is available.
4. Copy the public **Site Key**.
5. Keep the **Secret Key** private.
6. In `index.html`, replace:

```text
REPLACE_WITH_CLOUDFLARE_TURNSTILE_SITE_KEY
```

with the public Site Key. A Turnstile Site Key is intended for browser use;
the Secret Key must never be committed.

Deploy the updated frontend before enabling CAPTCHA in Supabase.

## Step 4 — Apply the Registration Migration

Run:

```text
supabase/migrations/20260721130000_protect_user_registration.sql
```

Then run:

```text
TESTING/sql/protected-registration-verification.sql
```

For the approved temporary email-only activation policy, then run:

```text
supabase/migrations/20260723214500_defer_mobile_verification.sql
```

and:

```text
TESTING/sql/email-only-activation-verification.sql
```

Expected SQL Editor result for both is:

```text
Success. No rows returned
```

Database changes:

- no duplicate profile or Auth table;
- five profile audit/verification columns;
- one Before User Created hook function;
- existing profile lifecycle functions hardened without signature changes;
- existing active-session pre-request guard extended with active-profile
  enforcement;
- existing `profiles.mobile` unique constraint retained.
- complete email-confirmed pending profiles activated without requiring mobile
  OTP; any existing mobile-verification timestamp is preserved.

## Step 5 — Enable the Before User Created Hook

In Supabase:

1. Open **Authentication → Hooks**.
2. Select **Before User Created**.
3. Select the Postgres function:

```text
public.hook_validate_user_registration
```

4. Save.

The hook rejects incomplete metadata, anonymous signup, non-email registration,
invalid mobile formatting, invalid referral values, empty subject choices,
duplicate subject choices, and inactive/unknown subjects before the Auth user
is created.

The profile trigger repeats this validation as a backstop.

## Step 6 — Configure the Email OTP Template

In **Authentication → Email Templates → Confirm signup**, include the Supabase
OTP token variable. Suggested template:

```html
<h2>Verify your InsureGPTE email address</h2>
<p>Your six-digit verification code is:</p>
<p style="font-size: 24px; font-weight: bold; letter-spacing: 4px;">
  {{ .Token }}
</p>
<p>Enter this code only on the official InsureGPTE registration page.</p>
<p>If you did not register, ignore this email.</p>
```

Keep **Confirm email** enabled. Confirm the Site URL and redirect allow-list
contain only approved InsureGPTE production and staging addresses.

## Step 7 — Defer Standard Phone Verification

Mobile OTP is not an activation requirement during the temporary email-only
phase. The mobile number remains mandatory, normalized, and unique.

1. Do not expose or commit existing SMS-provider credentials.
2. Phone-only signup remains rejected by the Before User Created hook.
3. Do not enable the frontend mobile-verification policy flag until a production
   SMS plan and the matching database rollback/change are approved.
4. Retain Twilio trial logs only as controlled-test evidence.

## Step 8 — Configure Password Policy

In **Authentication → Sign In / Providers → Email → Password security**:

1. Set minimum password length to **12**.
2. Require lowercase letters.
3. Require uppercase letters.
4. Require numbers.
5. Require symbols.

The frontend permits 12–64 characters and rejects spaces. Do not impose a
12-character maximum; longer passphrases are safer.

## Step 9 — Enable CAPTCHA in Supabase

After the frontend containing the correct Site Key is deployed:

1. Open **Authentication → Bot and Abuse Protection**.
2. Enable CAPTCHA protection.
3. Select **Cloudflare Turnstile**.
4. Enter the private Turnstile Secret Key.
5. Save.
6. Test an existing user's login before proceeding.

CAPTCHA applies to login as well as signup. The updated frontend contains a
widget and token handling for both flows.

## Step 10 — Controlled Registration Test

Keep public signup off and perform the first test in staging where possible.
When ready for a short production test:

1. Turn **Allow new users to sign up** on.
2. Leave **Allow anonymous sign-ins** off.
3. Register a new test learner using a real controlled email and mobile.
4. Confirm incomplete fields are rejected before network submission.
5. Confirm no registration is possible without a subject.
6. Confirm no registration is possible without Turnstile.
7. Enter the email OTP.
8. Confirm the profile becomes active and the dashboard opens directly.
9. Confirm a second account cannot reuse the same email or mobile number.
10. Confirm a direct phone-only signup is rejected.
11. Confirm Chrome/Edge and duplicate-tab session tests still pass.
12. Review Auth logs and rerun
    `TESTING/sql/email-only-activation-verification.sql`.

If any test fails, immediately turn **Allow new users to sign up** off again.

## Rollback

1. Turn **Allow new users to sign up** off.
2. To restore mandatory mobile OTP only, first run:

```text
supabase/rollbacks/20260723214500_defer_mobile_verification.sql
```

3. For a full protected-registration rollback, disable the Before User Created
   hook.
4. Disable Supabase CAPTCHA only if the previous deployed login page does not
   send CAPTCHA tokens.
5. Run:

```text
supabase/rollbacks/20260721130000_protect_user_registration.sql
```

The rollback intentionally retains the five new profile columns so collected
verification and referral history is not destroyed.

## Production Acceptance

Production registration is approved only when:

- audit results are reviewed;
- suspicious unverified users are quarantined;
- migration and verification SQL pass;
- hook, CAPTCHA, email OTP, and password policy are configured;
- mobile capture remains mandatory and unique while SMS OTP is deferred;
- valid and invalid registration tests pass;
- existing-user login passes;
- duplicate-tab and cross-browser session tests pass;
- no secret is committed to GitHub.
