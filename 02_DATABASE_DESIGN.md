# InsureGPTE Database Design

**Document:** `02_DATABASE_DESIGN.md`  
**Version:** 1.0  
**Status:** Architecture Freeze Draft  
**Project:** InsureGPTE  
**Database:** PostgreSQL through Supabase  
**Primary Schema:** `public`  
**Authentication Schema:** `auth`  
**Project Owner:** Sundararajan Desikan  
**Implementation Assistant:** ChatGPT Codex  
**Architecture and Review:** ChatGPT  

---

## 1. Purpose

This document defines the approved database architecture for InsureGPTE Version 1.0. It covers database domains, tables, relationships, business rules, integrity controls, indexing, RLS, migration priorities, and known design risks.

It is based on the current Supabase schema supplied for InsureGPTE and must remain consistent with:

- `PROJECT_CONTEXT.md`
- `CODING_RULES.md`
- `PROJECT_GOVERNANCE.md`
- `01_SYSTEM_ARCHITECTURE.md`

---

## 2. Database Design Principles

1. PostgreSQL is the authoritative system of record.
2. Supabase Auth is the authoritative source of user identity.
3. User ownership must be derived from `auth.uid()`.
4. The browser must not control privileged fields.
5. Referential integrity must be enforced with foreign keys.
6. Fixed-value states must use check constraints.
7. Business-critical calculations must run server-side.
8. Existing working tables and RPC signatures must be preserved unless formally approved.
9. Database migrations must be version controlled.
10. Destructive changes require explicit approval and rollback planning.
11. High-risk multi-step operations must use transactions.
12. User-owned tables must use RLS.
13. Repeated hierarchy values must remain internally consistent.
14. Premium access and quiz scoring must never depend on frontend trust.

---

## 3. Database Domain Map

### Identity and User

- `auth.users`
- `public.profiles`

### Academic Catalogue

- `qualification_levels`
- `exam_authorities`
- `training_programmes`
- `programme_sections`
- `subjects`
- `subject_modules`
- `subject_chapters`
- `subject_topics`

### Learning Content

- `learning_resource_types`
- `learning_resources`
- `flashcards`

### Question and Quiz

- `questions`
- `quiz_mode_config`
- `quiz_attempts`
- `quiz_attempt_questions`
- `attempts` — legacy review required

### Progress and Activity

- `user_topic_progress`
- `user_learning_activity`

### Commerce and Access

- `carts`
- `cart_items`
- `user_entitlements`

---

## 4. Entity Relationship Overview

```text
auth.users
    |
    +---- profiles
    +---- quiz_attempts
    +---- attempts
    +---- user_topic_progress
    +---- user_learning_activity
    +---- carts
    +---- user_entitlements

exam_authorities
    |
    +---- training_programmes
              |
              +---- programme_sections
              +---- subjects
                       |
                       +---- subject_modules
                       |        |
                       |        +---- subject_chapters
                       |                 |
                       |                 +---- subject_topics
                       |
                       +---- questions
                       +---- learning_resources
                       +---- flashcards
                       +---- quiz_attempts
                       +---- user_entitlements
                       +---- cart_items

quiz_attempts
    |
    +---- quiz_attempt_questions
              |
              +---- questions
```

---

# 5. Identity and User Domain

## 5.1 `auth.users`

Managed by Supabase Auth and used as the authoritative identity source.

```sql
auth.uid()
```

The frontend must never create its own identity, assign privileged roles, store passwords in application tables, or pass a trusted `user_id` where `auth.uid()` is sufficient.

## 5.2 `public.profiles`

### Purpose

Stores application-specific profile and account metadata.

### Primary Key

```text
id uuid → auth.users.id
```

### Important Columns

- `first_name`
- `last_name`
- `mobile`
- `company_name`
- `profession`
- address fields
- `interested_business_areas`
- `status`
- `role`
- `subscription_plan`

### Current Defaults

```text
status = verification_pending
role = user
subscription_plan = free
```

### Business Rules

1. One profile must exist per Auth user.
2. `id` must equal the Auth user ID.
3. The frontend must not set role, status, plan, or another user's ID.
4. Mobile uniqueness must be reviewed because international formatting and shared business numbers may exist.
5. Status transitions must be controlled server-side.

### Recommended Check Constraints

Approved profile states:

```text
status: verification_pending, active, suspended, closed
role: user, admin, instructor, moderator
subscription_plan: free, paid, premium, enterprise
```

### Recommended Indexes

```sql
CREATE INDEX IF NOT EXISTS idx_profiles_status
ON public.profiles(status);

CREATE INDEX IF NOT EXISTS idx_profiles_role
ON public.profiles(role);

CREATE INDEX IF NOT EXISTS idx_profiles_subscription_plan
ON public.profiles(subscription_plan);
```

### Security

RLS must allow users to read their own profile and update approved personal fields only. Privileged fields must be changed through secured server-side functions.

---

# 6. Academic Catalogue Domain

## 6.1 `qualification_levels`

Stores educational or qualification levels.

Existing controls:

- unique `code`;
- unique `name`;
- active flag;
- display order.

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_qualification_levels_active_order
ON public.qualification_levels(is_active, display_order);
```

## 6.2 `exam_authorities`

Stores examination bodies or recognised authorities.

Business rules:

1. `code` and `name` remain unique.
2. Disclaimer text should clarify InsureGPTE's independent status unless formally affiliated.
3. Inactive authorities must not appear in new catalogue selection.

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_exam_authorities_active_order
ON public.exam_authorities(is_active, display_order);
```

## 6.3 `training_programmes`

### Relationship

```text
exam_authority_id → exam_authorities.id
```

### Business Rules

1. A programme belongs to one exam authority.
2. Official pass percentage and recommended readiness percentage are separate concepts.
3. Programme codes should remain stable after publication.
4. `negative_marking` should preferably become `NOT NULL` with a default after rules are finalised.

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_training_programmes_authority_active
ON public.training_programmes(exam_authority_id, is_active, display_order);
```

## 6.4 `programme_sections`

### Relationship

```text
training_programme_id → training_programmes.id
```

### Business Rules

1. Section code should be unique within a programme.
2. Recommended practice count may differ from official exam count.
3. Only active sections should appear in active catalogue views.

Recommended unique constraint:

```sql
ALTER TABLE public.programme_sections
ADD CONSTRAINT uq_programme_sections_programme_code
UNIQUE (training_programme_id, code);
```

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_programme_sections_programme_active
ON public.programme_sections(training_programme_id, is_active, display_order);
```

## 6.5 `subjects`

### Relationships

- `qualification_level_id → qualification_levels.id`
- `training_programme_id → training_programmes.id`
- `programme_section_id → programme_sections.id`

### Business Rules

1. Subject code is unique.
2. Price cannot be negative.
3. Currency code has three characters.
4. Demo question limit cannot be negative.
5. A programme section must belong to the stated programme.
6. `is_demo_available = false` must prevent demo questions even when a positive limit exists.
7. `syllabus_version` should be required where content changes by exam cycle.

### Design Concern

The table repeats hierarchy references for convenient filtering. Consistency should be enforced through controlled RPCs or validation triggers.

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_subjects_programme_section_active
ON public.subjects(training_programme_id, programme_section_id, is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_subjects_qualification_active
ON public.subjects(qualification_level_id, is_active);

CREATE INDEX IF NOT EXISTS idx_subjects_demo
ON public.subjects(is_demo_available, demo_question_limit);
```

## 6.6 `subject_modules`

### Relationship

```text
subject_id → subjects.id
```

### Business Rules

1. A module belongs to one subject.
2. Module code should be unique within a subject.
3. Display order should be consistently managed within a subject.

Recommended unique constraint:

```sql
ALTER TABLE public.subject_modules
ADD CONSTRAINT uq_subject_modules_subject_code
UNIQUE (subject_id, code);
```

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_subject_modules_subject_active
ON public.subject_modules(subject_id, is_active, display_order);
```

## 6.7 `subject_chapters`

### Relationships

- `subject_id → subjects.id`
- `module_id → subject_modules.id`

### Business Rules

1. The module must belong to the selected subject.
2. Chapter number must be positive.
3. Chapter number should be unique within a module.
4. Chapter code should be unique within a subject.

Recommended constraints:

```sql
ALTER TABLE public.subject_chapters
ADD CONSTRAINT uq_subject_chapters_module_number
UNIQUE (module_id, chapter_number);

ALTER TABLE public.subject_chapters
ADD CONSTRAINT uq_subject_chapters_subject_code
UNIQUE (subject_id, code);
```

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_subject_chapters_module_active
ON public.subject_chapters(module_id, is_active, display_order);
```

## 6.8 `subject_topics`

### Relationships

- `subject_id → subjects.id`
- `module_id → subject_modules.id`
- `chapter_id → subject_chapters.id`

### Business Rules

1. Subject, module, and chapter must be mutually consistent.
2. Topic number must be positive and unique within a chapter.
3. Topic code should be unique within a subject.
4. Estimated study time must be positive when supplied.
5. Difficulty remains foundation, intermediate, or advanced.

Recommended constraints:

```sql
ALTER TABLE public.subject_topics
ADD CONSTRAINT uq_subject_topics_chapter_number
UNIQUE (chapter_id, topic_number);

ALTER TABLE public.subject_topics
ADD CONSTRAINT uq_subject_topics_subject_code
UNIQUE (subject_id, code);
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_subject_topics_chapter_active
ON public.subject_topics(chapter_id, is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_subject_topics_exam_relevant
ON public.subject_topics(subject_id, is_exam_relevant, is_active);
```

---

# 7. Learning Content Domain

## 7.1 `learning_resource_types`

Stores approved learning-content types such as notes, PDFs, videos, summaries, revision material, and external links.

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_learning_resource_types_active_order
ON public.learning_resource_types(is_active, display_order);
```

## 7.2 `learning_resources`

### Relationships

- subject;
- module;
- chapter;
- topic;
- resource type.

### Business Rules

1. All hierarchy IDs must describe the same path.
2. Resource code is globally unique.
3. Version and estimated reading time must be positive.
4. A resource should normally contain content, an external URL, or an attachment path.
5. Premium resources require an active entitlement.
6. Inactive resources are not returned to learners.
7. External URLs should be validated before publication.

Recommended data check after reviewing existing records:

```sql
CHECK (
    content IS NOT NULL
    OR external_url IS NOT NULL
    OR attachment_path IS NOT NULL
)
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_learning_resources_topic_active
ON public.learning_resources(topic_id, is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_learning_resources_topic_type
ON public.learning_resources(topic_id, resource_type_id, is_active);

CREATE INDEX IF NOT EXISTS idx_learning_resources_premium
ON public.learning_resources(subject_id, is_premium, is_active);
```

## 7.3 `flashcards`

### Business Rules

1. Hierarchy IDs must be consistent.
2. Code is globally unique.
3. Question and answer are mandatory.
4. Only active cards are returned.
5. Premium access follows the approved subject/content entitlement policy.

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_flashcards_topic_active
ON public.flashcards(topic_id, is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_flashcards_topic_difficulty
ON public.flashcards(topic_id, difficulty_level, is_active);
```

---

# 8. Question and Quiz Domain

## 8.1 `questions`

### Relationships

- subject;
- module;
- chapter;
- topic.

### Question Types

```text
MCQ
TRUE_FALSE
MULTIPLE_SELECT
ASSERTION_REASON
CASE_STUDY
```

### Business Rules

1. Hierarchy IDs must be mutually consistent.
2. Correct-answer format must match the question type.
3. Marks should be positive.
4. Negative marks cannot be negative and should not normally exceed marks.
5. A single-answer MCQ should have one defensible answer.
6. Multiple-select questions require a standard structured answer format.
7. Correct answers must not be exposed before permitted.
8. Inactive questions must not be allocated to new attempts.

### Design Concern

`correct_option` is text. It works for `A`, `B`, `C`, or `D`, but multiple-select questions require an agreed format. A future `jsonb` or option-table design may be considered only after reviewing existing quiz RPCs.

Recommended checks after data review:

```sql
CHECK (marks > 0)
CHECK (negative_marks >= 0 AND negative_marks <= marks)
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_questions_subject_active
ON public.questions(subject_id, is_active, difficulty_level);

CREATE INDEX IF NOT EXISTS idx_questions_topic_active
ON public.questions(topic_id, is_active, difficulty_level);

CREATE INDEX IF NOT EXISTS idx_questions_module_active
ON public.questions(module_id, is_active);

CREATE INDEX IF NOT EXISTS idx_questions_chapter_active
ON public.questions(chapter_id, is_active);
```

## 8.2 `quiz_mode_config`

Stores mode-level settings for practice, mock, and proctored mock tests.

Business rules:

1. One configuration row per mode.
2. Counts, attempt limits, and time limits must be positive.
3. Mock and proctored modes should normally use final-only feedback.
4. Inactive modes cannot start new attempts.
5. Only administrators may change configuration.

## 8.3 `quiz_attempts`

### Business Rules

1. Each attempt belongs to one authenticated user.
2. Attempt number must be sequential within its approved scope.
3. Counts cannot be negative.
4. Answered count cannot exceed total questions.
5. Percentage must remain between 0 and 100.
6. A completed attempt requires `completed_at`.
7. Completed attempts cannot be modified through ordinary answer RPCs.
8. Finalization must be idempotent.
9. Scope IDs must match `question_source`.
10. Subject, module, chapter, and topic must be mutually consistent.

Recommended checks after data review:

```sql
CHECK (answered_count >= 0 AND answered_count <= total_questions)
CHECK (correct_answers >= 0)
CHECK (wrong_answers >= 0)
CHECK (percentage >= 0 AND percentage <= 100)
CHECK (pass_percentage > 0 AND pass_percentage <= 100)
```

Potential unique constraint, subject to attempt-number scope review:

```sql
ALTER TABLE public.quiz_attempts
ADD CONSTRAINT uq_quiz_attempts_user_subject_mode_number
UNIQUE (user_id, subject_id, test_mode, attempt_number);
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_status
ON public.quiz_attempts(user_id, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_subject
ON public.quiz_attempts(user_id, subject_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_subject_mode
ON public.quiz_attempts(subject_id, test_mode, status);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_completed
ON public.quiz_attempts(user_id, completed_at DESC)
WHERE status = 'completed';
```

## 8.4 `quiz_attempt_questions`

### Business Rules

1. A question appears only once in an attempt.
2. Question order is unique within an attempt.
3. Correctness and marks are calculated server-side.
4. Time spent and answer-change count cannot be negative.
5. Answers must belong to the authenticated user's attempt.
6. Completed attempts reject normal answer changes.
7. Skipped state and selected answer must remain logically consistent.

Recommended constraints:

```sql
ALTER TABLE public.quiz_attempt_questions
ADD CONSTRAINT uq_quiz_attempt_questions_attempt_question
UNIQUE (attempt_id, question_id);

ALTER TABLE public.quiz_attempt_questions
ADD CONSTRAINT uq_quiz_attempt_questions_attempt_order
UNIQUE (attempt_id, question_order);
```

```sql
CHECK (time_spent_seconds >= 0)
CHECK (answer_changed_count >= 0)
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_quiz_attempt_questions_attempt
ON public.quiz_attempt_questions(attempt_id, question_order);

CREATE INDEX IF NOT EXISTS idx_quiz_attempt_questions_question
ON public.quiz_attempt_questions(question_id);
```

### Priority Design Concern

`marks_awarded` currently permits only `0` or `1`, while question marks are numeric. This prevents multi-mark, partial-mark, and negative-mark scoring. Any change must be coordinated with all existing scoring RPCs.

## 8.5 `attempts`

This appears to be an earlier simplified attempt table and overlaps with `quiz_attempts`.

### Recommendation

Treat it as legacy pending review. Codex must determine:

- whether frontend code still references it;
- whether any RPC uses it;
- whether historical data exists;
- whether it should be retained, migrated, archived, or deprecated.

Do not drop it without dependency analysis, backup, migration planning, and project-owner approval.

---

# 9. Progress and Activity Domain

## 9.1 `user_topic_progress`

### Business Rules

1. One row should exist per user and topic.
2. Completion remains between 0 and 100.
3. Time spent cannot be negative.
4. Completed status should normally mean 100% and a completed timestamp.
5. Not-started status should normally mean 0% and no completed timestamp.
6. Total time must not decrease.
7. Updates must use `auth.uid()`.

Required unique constraint:

```sql
ALTER TABLE public.user_topic_progress
ADD CONSTRAINT uq_user_topic_progress_user_topic
UNIQUE (user_id, topic_id);
```

Recommended check:

```sql
CHECK (total_time_spent_minutes >= 0)
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_user_topic_progress_user_status
ON public.user_topic_progress(user_id, status, last_accessed_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_topic_progress_topic
ON public.user_topic_progress(topic_id);
```

## 9.2 `user_learning_activity`

### Business Rules

1. Activity belongs to the authenticated user.
2. Duration cannot be negative.
3. Hierarchy IDs should be consistent where supplied.
4. `reference_id` meaning must be documented for each activity type.
5. Activity history should generally be append-only.

### Design Concern

`reference_id` is polymorphic and has no foreign key. This provides flexibility but weakens integrity. Its expected target per activity type must be documented in `04_RPC_DOCUMENTATION.md`.

Recommended check:

```sql
CHECK (duration_seconds >= 0)
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_user_learning_activity_user_time
ON public.user_learning_activity(user_id, activity_time DESC);

CREATE INDEX IF NOT EXISTS idx_user_learning_activity_topic_time
ON public.user_learning_activity(topic_id, activity_time DESC);

CREATE INDEX IF NOT EXISTS idx_user_learning_activity_type
ON public.user_learning_activity(user_id, activity_type, activity_time DESC);
```

---

# 10. Commerce and Access Domain

## 10.1 `carts`

### Business Rules

1. A user should have at most one active cart per currency.
2. Currency code contains three characters.
3. Converted carts cannot accept new items.
4. Ownership is validated with `auth.uid()`.

Recommended partial unique index:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_carts_one_active_per_user_currency
ON public.carts(user_id, currency_code)
WHERE status = 'active';
```

Recommended index:

```sql
CREATE INDEX IF NOT EXISTS idx_carts_user_status
ON public.carts(user_id, status, updated_at DESC);
```

## 10.2 `cart_items`

### Business Rules

1. A subject cannot appear twice in one cart.
2. Authoritative price comes from the server.
3. Browser-supplied `unit_price` is not trusted.
4. Currency must match the parent cart.
5. Converted or abandoned carts cannot be modified.

Required unique constraint:

```sql
ALTER TABLE public.cart_items
ADD CONSTRAINT uq_cart_items_cart_subject
UNIQUE (cart_id, subject_id);
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_cart_items_cart
ON public.cart_items(cart_id);

CREATE INDEX IF NOT EXISTS idx_cart_items_subject
ON public.cart_items(subject_id);
```

## 10.3 `user_entitlements`

### Business Rules

1. Access is validated server-side.
2. `valid_until` cannot precede `valid_from`.
3. Expired or revoked records do not grant access.
4. Creation and revocation must be auditable.
5. Purchased access follows verified payment.
6. Overlapping active entitlements must be handled intentionally.

Recommended check:

```sql
CHECK (valid_until IS NULL OR valid_until >= valid_from)
```

Recommended indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_user_entitlements_user_subject_status
ON public.user_entitlements(user_id, subject_id, status);

CREATE INDEX IF NOT EXISTS idx_user_entitlements_validity
ON public.user_entitlements(user_id, status, valid_from, valid_until);
```

Version 1.0 may allow historical entitlement rows while a secured grant RPC prevents unintended overlapping current access.

---

# 11. Cross-Table Integrity Rules

## Academic Hierarchy Validation

A reusable helper function, trigger, or secured content-management RPC should validate:

```text
subject → module → chapter → topic
```

This applies to:

- questions;
- learning resources;
- flashcards;
- quiz attempts;
- learning activity.

## Updated Timestamp Management

Tables with `updated_at` should use the existing `set_updated_at()` pattern consistently.

## Delete Behaviour

Recommended policy:

- restrict deletion of catalogue parents with children;
- retain or archive historical attempts and activity;
- use cascade only after dependency review;
- coordinate profile deletion with Auth and retention rules.

Do not introduce broad cascade deletion without review.

---

# 12. Row-Level Security Design

## Catalogue Data

Active catalogue metadata may be readable where required, but inactive and administrative data must be restricted.

## User-Owned Data

Users may access only their own:

- profile;
- quiz attempts;
- attempt questions through owned attempts;
- progress;
- activity;
- carts;
- entitlement information where appropriate.

## Administrative Data

Administrative writes require server-side role verification.

## Question Security

Learners must not directly query unrestricted `questions` rows if that exposes `correct_option`. Secure RPCs must omit restricted fields until feedback rules permit disclosure.

---

# 13. Recommended Views

Potential views, only where they simplify repeated safe reads:

- `vw_active_subject_catalogue`
- `vw_subject_hierarchy`
- `vw_user_current_entitlements`
- `vw_user_topic_progress_summary`
- `vw_completed_quiz_attempts`

Security and RLS behaviour must be reviewed before implementation.

---

# 14. Recommended Helper Functions

Potential helpers:

- validate academic hierarchy;
- check active entitlement;
- calculate quiz result;
- determine demo access;
- set updated timestamp;
- retrieve current user role;
- verify active account.

Helpers must not duplicate existing working logic.

---

# 15. Data Type Review

## Mixed IDs

The schema uses UUID, integer, and bigint. Recommended future convention:

- UUID for user-owned transactional roots;
- integer for academic catalogue;
- bigint for high-volume append/activity records.

Existing types should not be changed merely for cosmetic consistency.

## Score Types

The database mixes integer attempt scores, numeric question marks, and integer marks awarded. These must be aligned before advanced marking is introduced.

## Currency

Future enhancement: uppercase validation and an optional supported-currency reference table.

## Status Values

Text plus check constraints remains acceptable for Version 1.0. PostgreSQL enums are not required.

---

# 16. Priority Database Findings

## Critical

1. Verify RLS on every sensitive and user-owned table.
2. Prevent direct exposure of `questions.correct_option`.
3. Add unique `(user_id, topic_id)` to `user_topic_progress` after duplicate checks.
4. Add attempt-question and attempt-order uniqueness after duplicate checks.
5. Review the `marks_awarded` 0/1 limitation.
6. Review use of the legacy `attempts` table.

## High

1. Add hierarchy-consistency validation.
2. Add cart-item uniqueness.
3. Prevent multiple active carts per user and currency.
4. Add entitlement date validation.
5. Add explicit profile status, role, and plan checks.
6. Standardise multiple-select answer storage.

## Medium

1. Add missing indexes.
2. Apply updated-at triggers consistently.
3. Document `user_learning_activity.reference_id`.
4. Review nullable hierarchy IDs in `questions`.
5. Standardise currency casing.
6. Review foreign-key delete behaviour.

---

# 17. Migration Execution Plan

## Pack 1 — Safety and Inventory

- export current functions;
- export RLS policies;
- identify dependencies;
- inspect duplicate objects;
- inspect data quality;
- verify legacy `attempts` usage.

## Pack 2 — Non-Destructive Indexes

- foreign-key indexes;
- activity indexes;
- attempt indexes;
- catalogue indexes;
- entitlement indexes.

## Pack 3 — Safe Unique Constraints

After duplicate checks:

- user-topic uniqueness;
- attempt-question uniqueness;
- attempt-order uniqueness;
- cart-subject uniqueness;
- hierarchy code/number uniqueness.

## Pack 4 — Check Constraints

After invalid-data checks:

- profile states;
- score boundaries;
- non-negative time;
- entitlement date order;
- marks rules.

## Pack 5 — Hierarchy Validation

- validation helper;
- controlled triggers or write RPCs;
- verification tests.

## Pack 6 — Quiz Marking Alignment

- review mark types;
- update scoring RPCs;
- complete regression testing.

## Pack 7 — Legacy Cleanup

- archive or migrate `attempts`;
- remove only after approval.

---

# 18. Database Testing Requirements

Every migration must test:

- valid insertion;
- invalid insertion;
- duplicate prevention;
- foreign-key enforcement;
- cross-user access;
- anonymous access;
- admin access;
- rollback feasibility;
- existing RPC compatibility.

Quiz tests must include:

- no available questions;
- fewer questions than requested;
- duplicate allocation;
- duplicate submission;
- completed or abandoned attempt;
- unauthorized attempt;
- immediate and final-only feedback;
- score consistency.

Entitlement tests must include:

- active;
- future;
- expired;
- revoked;
- absent;
- demo-only;
- overlapping records.

---

# 19. Codex Database Review Instructions

```text
1. Read PROJECT_CONTEXT.md.
2. Read CODING_RULES.md.
3. Read PROJECT_GOVERNANCE.md.
4. Read 01_SYSTEM_ARCHITECTURE.md.
5. Read 02_DATABASE_DESIGN.md.
6. Inspect live repository SQL and frontend references.
7. Inventory functions, triggers, RLS policies, indexes, and views.
8. Identify objects already present.
9. Do not create duplicate objects.
10. Do not drop or rename existing objects without approval.
11. Produce a written review before migration SQL.
12. Separate migrations into safe executable packs.
13. Include verification and rollback guidance.
```

---

# 20. Architecture Approval Checklist

This document is ready to freeze when the project owner confirms:

- current tables are accurately represented;
- `attempts` is treated as pending legacy review;
- the academic hierarchy remains approved;
- quiz, progress, and entitlement rules are accepted;
- priority findings are accepted;
- migrations will be incremental;
- destructive changes require separate approval.

---

# 21. Next Document

After approval, proceed to:

```text
04_RPC_DOCUMENTATION.md
```

It will catalogue existing and planned RPCs, parameters, returns, authorization, affected tables, frontend consumers, test cases, and implementation status.
