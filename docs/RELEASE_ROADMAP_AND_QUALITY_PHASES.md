# InsureGPTE Release Roadmap

## Current Baseline

- Demo mode is limited to 10 advanced questions per subject.
- Demo options are shuffled server-side by `get_attempt_questions`.
- Demo scoring is preserved server-side by comparing the submitted answer text with the stored correct answer.
- Demo cooldown is enforced by Supabase.
- Demo lifetime attempt limits have been removed.
- The final answer explanation remains visible until the learner explicitly finishes.
- Demo results return to the Subject Catalogue.
- Active practice results return to My Practice.
- The 30 demo questions for IC01, IC11, and IC14 were audited and rebalanced to A/B/C/D distributions of 3/3/2/2 per subject.
- Duration pricing is configured as 15/30/60/90 days at INR 99/149/249/349.
- Cart prices and durations are server-authoritative and read-only in the browser.
- Learning entry is free for active registered users.
- The legacy `subjects.price` fallback for active subjects is INR 349, while duration plans remain authoritative.

## Progress Update - 2026-09-17

- Administrator duration pricing editor is deployed and tested.
- Price updates are server-authorized and recorded with old/new values in audit history.
- Catalogue and cart reflect the saved duration-plan prices.
- IC01, IC11, and IC14 demo flows were tested; IC01 active practice loaded 50 questions.
- Root cause found for administrator IC01 demo failure: the legacy unique constraint omitted `test_mode` and conflicted with practice attempt numbering.
- Migration `20260917110000_separate_demo_and_practice_attempts.sql` was applied successfully and pushed to origin.
- Demo and practice attempt numbering is now independent.
- Frontend verification confirms registered users without active purchases can start free demos, while paid practice remains blocked.
- Remaining pre-live work: verified payment entitlement creation, payment safeguards, and final regression checks.

## Pre-Live Release Requirements

1. [x] Add an administrator-only editor for the four duration-plan prices.
2. [x] Protect price changes with server-side administrator verification.
3. [x] Record every price change in the administrator audit history.
4. [x] Confirm catalogue, subject detail, and cart all display the current server-side plan prices.
5. Implement verified-payment entitlement creation.
6. Ensure payment, webhook, refund, and reconciliation paths cannot be triggered by browser-supplied prices.
7. [x] Confirm normal users cannot access administrator pricing controls.
8. Run the complete SQL and browser regression suite, including the verified free-demo and paid-practice entitlement boundary.
9. Push the tested branch and verify the Vercel preview before merging to `main`.

## Final Quality Phases

These phases remain on the test branch after the initial live release and must be completed before their merge into `main`.

### 1. Active Mock-Test Integrity

- [x] Apply server-side question and answer-option shuffling to active practice tests.
- Regression-test the existing five-attempt limit per subject.
- Regression-test the existing 50-question selection per attempt.
- Regression-test the existing scoring and attempt tracking after shuffling.
- Verify IC01, IC11, and IC14 independently.
- Confirm option shuffling remains stable when an attempt is reloaded.
- Confirm scoring remains correct after question and option shuffling.
- Confirm practice access remains entitlement-gated.
- [x] Confirm demos and practice attempts remain counted independently.

Verification note: `TESTING/sql/server-side-option-shuffle-verification.sql`
checks the deployed RPC definition and answer protection. It does not by
itself execute a live 50-question practice attempt. The remaining action is
to run an active-practice verification using an entitled test user, then
complete the browser checks for IC01, IC11, and IC14.

### 2. Question Quality Audit

- Confirm exactly one correct answer per question.
- Confirm every correct answer exactly matches one option.
- Ensure distractors are closely related to the question but definitively incorrect.
- Remove duplicate and near-duplicate options.
- Remove answer-length patterns that reveal the correct option.
- Balance correct-answer positions across A, B, C, and D.
- Review question wording, explanations, and distractors for insurance-domain accuracy.
- Produce an audit result before modifying question-bank records.

### 3. Learning-Content Completeness

- Verify every active subject has a complete learning structure.
- Verify every topic contains explanatory content rather than only index metadata.
- Verify each chapter has useful reading material and a Quick Recap.
- Ensure Quick Recap contains the important points from that chapter and subject.
- Complete IC14 resources and flashcards topic by topic.
- Confirm flashcards remain free for active registered users.
- Keep premium practice content and practice attempts entitlement-gated.
- Run a subject-by-subject content completeness audit.

## Merge Gate

No change from a final quality phase may merge into `main` until:

- SQL verification succeeds.
- Browser verification succeeds on the Vercel preview.
- Administrator and normal-user permission paths are tested separately.
- No production data is modified without a migration and rollback strategy.
- The relevant audit output is saved with the change.

## Working Branch

Primary test branch: `test/ic11-ic14-learning-content`

Production branch: `main`
