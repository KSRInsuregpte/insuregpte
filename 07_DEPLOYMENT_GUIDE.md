# Deployment Guide

## Catalogue-first learning and practice release

This release must be deployed in the following order so the new frontend never
calls database functions that are not yet available.

### 1. Confirm prerequisites

Confirm the existing registration, email-only activation, active-session, quiz,
academic hierarchy, cart, and entitlement objects are already deployed.

Run the repository tests:

```text
npm test
```

### 2. Deploy the catalogue migration

Run:

```text
supabase/migrations/20260725120000_launch_subject_catalogue.sql
```

Then run:

```text
TESTING/sql/catalogue-commerce-verification.sql
```

Expected result: `Success. No rows returned`.

This migration does not create tables. It:

- changes new registration to version 3 without subject selection;
- preserves the existing registration function signatures;
- grants complimentary entitlements for valid legacy registration subjects;
- adds secured catalogue and cart RPCs.

### 3. Deploy the demo and entitlement gate

Run:

```text
supabase/migrations/20260725121000_gate_quiz_access_and_enable_demo.sql
```

Then run:

```text
TESTING/sql/demo-entitlement-quiz-verification.sql
```

Expected result: `Success. No rows returned`.

### 4. Review catalogue data

Before publishing the frontend, confirm for every active subject:

- category, qualification, programme, and broker stream are correct;
- price and currency are correct;
- demo availability is intentional;
- demo-enabled subjects have at least ten active `advanced` questions;
- learning-content availability reflects the current resource records.

### 5. Deploy the frontend

Deploy the repository version containing:

- `catalogue.html`
- `subject.html`
- `cart.html`
- the entitlement-driven `dashboard.html`
- the version-3 registration and demo-enabled test page.

Do not enable a checkout or payment-success button in the browser. Payment
provider selection, server order creation, signed webhook verification,
reconciliation, and entitlement granting remain a separate approved release.

### 6. Controlled smoke test

Use one controlled learner account to complete the catalogue and demo checks in
`06_TESTING_GUIDE.md`. Keep anonymous sign-in disabled.

## Rollback

Rollback must be performed in reverse order:

1. `supabase/rollbacks/20260725121000_gate_quiz_access_and_enable_demo.sql`
2. `supabase/rollbacks/20260725120000_launch_subject_catalogue.sql`

The rollback scripts intentionally stop if demo history or version-3
registrations exist. Do not delete learner data merely to force a rollback;
prepare a forward correction instead.

## Administrator portal release

Deploy the administrator release only after the catalogue, entitlement, and
regulatory metadata migrations have passed verification.

1. Run `supabase/migrations/20260727180000_build_admin_portal.sql`.
2. Run `TESTING/sql/admin-portal-verification.sql`.
3. Confirm the expected result is `Success. No rows returned`.
4. Deploy `admin-dashboard.html`, `js/admin.js`, and the updated dashboard/login
   files.
5. Complete the controlled administrator checks in `06_TESTING_GUIDE.md`.

The migration must run before the frontend is deployed. The rollback file is
`supabase/rollbacks/20260727180000_build_admin_portal.sql`. Rollback removes
the admin RPCs and audit-history table but intentionally preserves subject,
question, user-status, and examination-information business records changed by
administrators. Direct browser writes to subjects and questions remain revoked.

### Administrator bulk-upload extension

After the Admin portal and question-answer repair are verified:

1. Deploy `20260730150000_add_admin_bulk_import.sql`.
2. Run `TESTING/sql/admin-bulk-import-verification.sql`.
3. Deploy `20260731120000_expand_admin_bulk_import.sql`.
4. Run `TESTING/sql/admin-expanded-bulk-import-verification.sql`.
5. Deploy the trial branch frontend to Vercel Preview.
6. Complete the controlled checks in `06_TESTING_GUIDE.md`.

Do not deploy the expanded frontend before both migrations pass. Roll back in
reverse timestamp order. Imported business records remain audited and are not
automatically deleted.

Do not add live checkout during this release. Payment order creation, provider
credentials, signed webhook verification, reconciliation, refunds, and
entitlement fulfilment require a separately approved payment-provider design.
