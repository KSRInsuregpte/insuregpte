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
