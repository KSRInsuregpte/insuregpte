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
