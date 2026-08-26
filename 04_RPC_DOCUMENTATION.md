# RPC Documentation

## Catalogue and access release

The catalogue release reuses the existing academic, commerce, entitlement, and
quiz tables. The frontend must use these RPCs instead of reading or writing
their tables directly.

### `get_subject_catalogue()`

- Roles: `anon`, `authenticated`
- Parameters: none
- Purpose: returns active subjects with their qualification/programme
  classification, price, demo readiness, learning-content availability, and
  caller-specific cart/entitlement state.
- Security: `SECURITY DEFINER`, empty `search_path`.
- Important rule: public callers receive the catalogue, but an entitlement is
  true only when the authenticated caller owns a currently active entitlement.

### `add_subject_to_cart(p_subject_id bigint)`

- Role: `authenticated`
- Returns: active cart UUID
- Purpose: adds one active, paid subject to the learner's active cart.
- Security: verifies the active learner profile, reads the price and currency
  from the server, prevents duplicate items, and rejects subjects already
  covered by an active entitlement.
- Important rule: the browser never supplies the price.

### `remove_subject_from_cart(p_subject_id bigint)`

- Role: `authenticated`
- Returns: `void`
- Purpose: removes the subject only from the authenticated learner's active
  cart.

### `get_my_cart()`

- Role: `authenticated`
- Parameters: none
- Purpose: returns the authenticated learner's active cart items and the
  authoritative prices recorded when each item was added.

### `start_quiz_attempt(p_subject_id bigint, p_test_mode text)`

The existing function signature and return columns are preserved.

The catalogue release extends the implementation as follows:

- `demo` is an explicit quiz mode;
- demo allocation uses up to ten active `advanced` questions;
- paid practice modes require a currently active `user_entitlements` row;
- demos and practice attempts are counted independently;
- attempt creation remains serialized and resumes an existing in-progress
  attempt for the same subject and mode.

## Payment boundary

No frontend action may create an entitlement. A future checkout implementation
must create a server-side payment order, validate the provider's signed webhook,
reconcile the successful payment, and only then grant the entitlement.

## Examination information

### `get_exam_information(p_authority_code, p_session_code, p_subject_code)`

- Role: `authenticated`
- Purpose: returns current verified examination schedules, centre lists, and
  language notices from the governed regulatory source register.
- Hierarchy: results are linked to existing exam authorities, subjects,
  training programmes, and programme sections where the source is
  subject-specific.
- Session rule: expired rows are excluded using `valid_until` and the database
  current date.
- Privacy: no profile, authentication, contact, or learner data is read.
- Security: `SECURITY DEFINER`, empty `search_path`; direct browser access to
  `regulatory_academic_publications` is revoked.
- Audit fields: each row returns its source document identifier, verification
  status, and verification date.

## Administration release

All functions below are granted only to `authenticated`; each function also
calls `fn_is_admin()` and rejects a caller unless the current profile has
`role = admin` and `status = active`.

### Authorization and overview

- `fn_is_admin()` returns the current caller's administrator state.
- `get_admin_portal_summary()` returns aggregate counts and active academic
  hierarchy options used by the admin forms.

### Subject and question management

- `admin_list_subjects()` returns the complete subject master with hierarchy
  labels and active-question counts.
- `admin_save_subject(p_subject jsonb)` creates an inactive subject or updates
  an existing subject after validating hierarchy, price, currency, demo, and
  activation rules.
- `admin_list_questions(p_subject_id bigint)` returns the selected subject's
  current MCQ bank for administrator editing.
- `admin_save_question(p_question jsonb)` creates or updates an MCQ and maps
  Easy, Moderate, and Hard to `foundation`, `intermediate`, and `advanced`.
  The form submits an A/B/C/D tag, but the RPC resolves that tag and stores the
  corresponding full option text required by the existing quiz scorer.

### User and examination-information management

- `admin_list_users()` returns registered user and verification information to
  administrators only.
- `admin_set_user_status(p_user_id uuid, p_status text)` supports only
  `active` and `verification_pending`. It cannot change passwords or roles.
- `admin_list_exam_information()`, `admin_save_exam_information(p_information
  jsonb)`, and `admin_retire_exam_information(p_information_id bigint)` manage
  official-source metadata without deleting historical rows.
- `admin_list_audit_events(p_limit integer)` returns the latest administrator
  changes. Question answers and user contact values are not copied into the
  audit summary.

The migration creates only `admin_audit_events`; it reuses all academic,
profile, question, Auth, and regulatory tables identified by the live audit.

### Bulk administration

- `admin_bulk_import(p_entity text, p_rows jsonb)` atomically coordinates
  1-250 reviewed CSV rows. It delegates existing subjects, questions, user
  status, and exam information to their established save functions.
- `admin_save_academic_content(p_entity text, p_record jsonb)` creates or
  updates approved qualification, authority, programme, programme-section,
  module, chapter, topic, resource-type, resource, or flashcard records by
  stable code. It validates the complete hierarchy path and writes one
  `admin_audit_events` row.
- `admin_save_entitlement(p_entitlement jsonb)` creates or updates only
  `complimentary`, `promotional`, and `admin_grant` access for an existing
  active user. Purchase and subscription entitlements are rejected.

The bulk release creates no data table. `admin_save_exam_information(jsonb)`
also accepts `official_notice` and verifies that programme and section
references belong to their stated authority and programme.

## Learning Module controlled release

All Learning functions are granted only to `authenticated`, require
`auth.uid()`, and reject inactive profiles. Browser roles have no direct table
privileges on the learning hierarchy, resource, flashcard, progress, or
activity tables.

- `get_subject_hierarchy(p_subject_id)` returns the ordered module, chapter,
  and topic path with owned progress and content counts.
- `get_modules_by_subject(p_subject_id)`,
  `get_chapters_by_module(p_module_id)`, and
  `get_topics_by_chapter(p_chapter_id)` provide independently reusable hierarchy
  reads.
- `get_topic_details(p_topic_id)` returns the active topic and its breadcrumb,
  learning objective, practical relevance, owned progress, and access state.
- `get_learning_resources(p_topic_id)` returns active resources. Premium
  content, URL, and attachment fields are `NULL` without a current entitlement.
- `get_flashcards(p_topic_id)` returns active cards only to a currently entitled
  learner.
- `record_learning_activity(...)` validates ownership, hierarchy, access,
  reference type, duration, and progress before atomically appending activity
  and updating topic progress.
- `get_resume_learning(p_subject_id)`, `get_recent_activity(p_limit)`,
  `get_topic_completion(p_topic_id)`, and
  `get_learning_statistics(p_subject_id)` return only the current learner's
  resumable state and aggregates.

The legacy `upsert_user_topic_progress` signature remains compatible but now
requires `p_user_id = auth.uid()` and is no longer executable anonymously. See
`docs/LEARNING_MODULE.md` for the activity-reference contract and trial plan.
