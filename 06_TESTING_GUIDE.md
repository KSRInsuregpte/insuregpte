# Testing Guide

## Quiz start diagnostics

The quiz start button reports two separate runtime stages:

1. `Creating Attempt...` calls `start_quiz_attempt`.
2. `Loading Questions...` calls `get_attempt_questions`.

Each request has a 20-second client timeout. A timeout restores the start button
and identifies the stalled RPC. Retrying `start_quiz_attempt` is safe because
the deployed function resumes the latest in-progress attempt for the same user,
subject, and test mode.

When investigating a start failure, record:

- the stage displayed immediately before the error;
- the user-facing error message;
- the browser console error;
- the subject ID and code in the page URL;
- whether the deployed `test.html` matches the repository version.

Static verification:

```text
npm test
```

## Quiz completion flow

After the final answer is recorded:

1. The completed quiz result remains visible on `test.html`.
2. The page does not call logout and does not navigate automatically.
3. **Return to Subject Selection** releases only the page-level lock and opens
   `dashboard.html` with the existing authenticated session.
4. The dashboard reloads `get_my_quiz_attempts` and counts every created
   attempt status, including `in_progress`, `completed`, and `abandoned`.

The automated completion check uses a recorded 50-of-50 completion response,
verifies that no automatic navigation occurs, and verifies the attempt counter
with multiple statuses:

```text
node TESTING/quiz-completion-behavior-check.mjs
```

Production smoke testing must confirm:

- the final result is shown after question 50;
- the learner remains signed in;
- selecting **Return to Subject Selection** opens the dashboard;
- the relevant subject's **Attempts Used** increases immediately;
- only the explicit **Logout** button returns the learner to the login screen.

## Active quiz exit flow

Before **Start This Attempt** is selected, **Back** and **Logout** retain their
normal behavior.

After an attempt starts:

1. **Back** and **Back to Dashboard** become **Finish Attempt & Return**.
2. **Logout** becomes **Finish Attempt & Logout**.
3. Each exit opens an accessible confirmation explaining that submitted
   answers will be scored and unanswered questions will receive zero.
4. **Continue Quiz** closes the confirmation without calling an RPC or
   navigating.
5. A confirmed exit calls the existing
   `finalize_quiz_attempt(p_attempt_id uuid)` RPC.
6. Dashboard navigation or global logout occurs only after the RPC succeeds.
7. A failed finalization keeps the learner on the quiz and displays the error.
8. Closing or refreshing the browser unexpectedly does not call finalization;
   the existing `in_progress` attempt remains available for recovery.

Production smoke testing must separately confirm:

- **Finish Attempt & Return** records the partial result before opening the
  dashboard;
- **Finish Attempt & Logout** records the partial result before opening the
  login page;
- **Continue Quiz** leaves the attempt active;
- a simulated or observed finalization error prevents both navigation and
  logout;
- an unexpected tab closure preserves the attempt for recovery.

## Catalogue, registration, cart, and demo

Static verification:

```text
npm test
```

Database verification after the catalogue migration:

```text
TESTING/sql/catalogue-commerce-verification.sql
```

Database verification after the demo/entitlement migration:

```text
TESTING/sql/demo-entitlement-quiz-verification.sql
```

Controlled runtime testing must confirm:

- registration succeeds without choosing subjects;
- the catalogue is available before login;
- category filtering and subject search work;
- Learning, Free Demo, and Add to Cart reflect each subject's database state;
- an authenticated learner can add and remove a subject from the cart;
- a demo starts only when ten active `advanced` questions are available;
- demo attempts do not change the paid practice-attempt count;
- a learner without an active entitlement cannot start paid practice;
- a learner with a migrated complimentary or purchased entitlement can start
  paid practice;
- checkout remains disabled until payment webhook processing is implemented.

## Administrator portal

Run the repository static checks, then deploy:

```text
supabase/migrations/20260727180000_build_admin_portal.sql
```

Run:

```text
TESTING/sql/admin-portal-verification.sql
```

Expected result: `Success. No rows returned`.

Controlled browser checks:

1. A normal learner does not see **Administration** on `dashboard.html`.
2. Opening `admin-dashboard.html` as a normal learner shows no management data.
3. The active administrator sees the Administration link and dashboard.
4. Create a new inactive subject, edit it, and confirm an audit-history row.
5. Create and edit one controlled MCQ; verify Easy, Moderate, and Hard render
   correctly and the correct answer/explanation persist.
6. Change a controlled email-verified user between `verification_pending` and
   `active`; confirm passwords and roles are unchanged.
7. Add one controlled future examination notice and retire it; confirm it no
   longer appears through the learner examination-information RPC.
8. Confirm anonymous and normal authenticated browser roles cannot read or
   write `subjects`, `questions`, or `admin_audit_events` directly.
