# InsureGPTE Safety System Deployment

## Purpose

This release adds an administrator-reviewed safety workflow without replacing
Supabase Auth or changing the existing profile/session/quiz RPC signatures.
It records privacy-safe alerts, controlled learner cases, and notification
delivery work. It does not store passwords, OTPs, tokens, raw Auth payloads,
full IP addresses, question text, or answer values.

## Included

- immediate administrator dashboard alert when a pending registration becomes
  active after email verification;
- administrator-triggered scanning of currently active page leases that have
  remained continuously claimed for more than 48 hours;
- a service-role-only event-ingestion RPC for future approved Vercel,
  Supabase, or security-monitor integrations;
- review, dismissal, case opening, three-warning, critical suspension,
  restoration, and audit controls;
- learner warning notices on every authenticated catalogue, subject, cart,
  dashboard, and practice page;
- a durable email notification outbox and service-role-only worker RPCs;
- a matching rollback and read-only verification SQL.

## Intentionally not automatic

- Ordinary unusual activity never suspends a learner automatically.
- Service-pressure and provider attack signals are not invented by the
  browser. They require an approved trusted server-side monitor to call
  `record_security_event`.
- Email messages remain in the outbox until an approved server-side mail worker
  is configured. No SMTP or service-role secret belongs in frontend code.
- SMS notifications remain deferred until a production SMS provider is
  separately approved.

## Trial deployment order

1. Confirm a Supabase database backup is available.
2. Run:
   `supabase/migrations/20260802150000_add_safety_monitoring_and_enforcement.sql`
3. Run the safety-event insert repair:
   `supabase/migrations/20260803100000_repair_security_event_insert.sql`
4. Run:
   `TESTING/sql/safety-system-verification.sql`
5. Run the transactional execution check:
   `TESTING/sql/security-event-insert-repair-verification.sql`
6. Confirm both verification scripts return **Success. No rows returned**.
7. Deploy the `agent/safety-system` branch to a Vercel preview.
8. Test with one administrator and one standard learner account.
9. Do not merge into `main` until the controlled tests below pass.

## Controlled acceptance tests

### Authorization

- An anonymous visitor cannot open the admin portal or execute safety RPCs.
- A standard learner cannot list security events, cases, or the outbox.
- Only an active administrator can review alerts and apply actions.
- Only the service role can claim or complete email outbox rows.

### Registration notification

- Complete one controlled email-confirmed registration.
- Confirm an informational `Registration Confirmed` event appears.
- Confirm an administrator email row is pending in the outbox.
- Confirm the informational event cannot open an enforcement case.

### Long-running session

- Use trial data or a controlled timestamp adjustment to represent a lease
  claimed for more than 48 hours while still unexpired.
- Select **Check Sessions Over 48 Hours**.
- Confirm one reviewable event is created without blocking the learner.

### Warning policy

- Open a case from a non-informational learner event.
- Issue warning 1, warning 2, and warning 3.
- Confirm each warning is visible on every authenticated learner page within
  15 seconds, or immediately when that page regains focus, until acknowledged.
- Confirm a fourth warning is rejected by PostgreSQL.
- Confirm ordinary suspension before warning 3 is rejected.

### Suspension and restoration

- After warning 3, suspend the controlled learner.
- Confirm the learner's active page is displaced within one heartbeat cycle,
  the local session is cleared, and login explains that the account is
  suspended or inactive.
- Confirm the administrator account cannot be selected for learner suspension.
- Restore the learner and confirm a new login can acquire page control.
- Confirm all actions appear in Administrator Audit History.

### Administrator interaction

- Confirm review, warning, suspension, and restoration open an on-page form,
  not a browser prompt.
- Confirm the form requires an auditable note or reason, supports Cancel and
  Escape, and returns keyboard focus to the triggering action.
- Confirm Vercel's interaction diagnostic no longer reports the multi-second
  browser-dialog delay for these safety actions.

### Critical event

- Through a controlled service-side test, create a linked `critical_attack`
  event.
- Confirm the administrator may suspend immediately, but the action still
  requires explicit confirmation and a reason.

### Regression

- Login, registration, catalogue, dashboard, learning, quiz, logout, admin
  content, and bulk upload continue to operate normally.

## Email worker boundary

A future server-side worker must:

1. hold the Supabase service-role and SMTP/API secrets outside the browser;
2. call `claim_notification_outbox(integer)`;
3. send only to the returned recipient addresses;
4. call `complete_notification_outbox(bigint,boolean,text)`;
5. redact provider errors before saving them;
6. retry no more than the database-controlled five attempts.

## Rollback

To roll back only the safety-event insert implementation, run:
`supabase/rollbacks/20260803100000_repair_security_event_insert.sql`

This safe rollback continues to rely on the existing `updated_at` table
default; it does not restore the malformed statement that prevented safety
events from being recorded.

To remove the complete safety system, run:
`supabase/rollbacks/20260802150000_add_safety_monitoring_and_enforcement.sql`

The rollback restores learners suspended by an open safety case, removes the
safety tables/RPCs/trigger, and preserves existing administrator audit history.
The expanded audit entity-type constraint remains so retained history stays
valid.
