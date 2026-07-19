# InsureGPTE™ Coding Rules

**Document Version:** 1.0  
**Project:** InsureGPTE  
**Status:** Active Development  
**Purpose:** Define mandatory engineering, database, security, frontend, testing, and repository standards for all contributors and AI coding assistants.

---

## 1. Core Development Principles

1. GitHub is the single source of truth for the project.
2. All code changes must be made in the repository and committed with a clear message.
3. Do not make undocumented changes directly in production.
4. Follow this sequence for each feature:

   Database  
   → RPC/API  
   → Frontend  
   → Testing  
   → Deployment

5. Preserve existing working functionality unless a verified defect requires modification.
6. Do not duplicate tables, RPCs, triggers, views, or business logic.
7. Before creating a new database object, verify whether an equivalent object already exists.
8. Prefer maintainable, readable solutions over clever or highly compressed code.
9. Do not introduce frameworks, libraries, or services without documenting why they are required.
10. Any change that affects the database, authentication, quiz engine, entitlements, or payment flow must include a rollback plan.

---

## 2. Project Scope Rules

InsureGPTE Version 1.0 is an insurance education, learning, revision, examination preparation, assessment, and progress-tracking platform.

The following are outside the Version 1.0 scope unless formally approved:

- Insurance CRM
- Policy administration
- Claims management
- Reinsurance placement
- Recruitment
- Placement services
- General accounting
- ERP
- Certification issuing by InsureGPTE
- Unrelated e-commerce features

Do not add out-of-scope features without explicit approval.

---

## 3. Repository Structure

Use the following repository structure:

```text
/
├── README.md
├── PROJECT_CONTEXT.md
├── CODING_RULES.md
├── CHANGELOG.md
├── package.json
├── frontend/
│   ├── pages/
│   ├── components/
│   ├── assets/
│   │   ├── css/
│   │   ├── js/
│   │   └── images/
│   └── config/
├── database/
│   ├── schema/
│   ├── migrations/
│   ├── seeds/
│   ├── indexes/
│   ├── triggers/
│   ├── views/
│   ├── functions/
│   └── rpc/
├── supabase/
│   ├── migrations/
│   └── config/
├── docs/
├── testing/
└── scripts/
```

Existing root-level HTML files may remain temporarily during migration, but new work should follow the structure above.

---

## 4. File Naming Rules

Use lowercase file names with hyphens.

Examples:

```text
student-dashboard.html
quiz-review.html
subject-catalogue.js
learning-progress.css
```

SQL files must use ordered prefixes where execution order matters.

Examples:

```text
001-create-base-tables.sql
002-create-indexes.sql
003-create-triggers.sql
004-create-rpcs.sql
```

Migration files must be immutable after successful production deployment.

---

## 5. SQL Naming Standards

Use lowercase `snake_case`.

### Tables

Use descriptive plural nouns.

Examples:

```text
subjects
subject_modules
quiz_attempts
user_topic_progress
```

Do not add `tbl_` prefixes to existing tables.

### Primary Keys

Use:

```text
id
```

Preferred types:

- `uuid` for user-owned, transactional, commerce, and externally referenced entities
- `integer` or `bigint` for academic catalogue and high-volume activity records

### Foreign Keys

Use:

```text
<referenced_entity>_id
```

Examples:

```text
subject_id
module_id
chapter_id
topic_id
user_id
```

### Indexes

Use:

```text
idx_<table>_<column_or_purpose>
```

Example:

```text
idx_quiz_attempts_user_status
```

### Unique Constraints

Use:

```text
uq_<table>_<column_or_purpose>
```

### Check Constraints

Use:

```text
chk_<table>_<business_rule>
```

### Foreign Key Constraints

Use:

```text
fk_<table>_<referenced_table>
```

### Triggers

Use:

```text
trg_<table>_<action>
```

### Views

Use:

```text
vw_<business_purpose>
```

### Helper Functions

Use:

```text
fn_<business_purpose>
```

### RPC Functions

Use clear action-oriented names without unnecessary prefixes.

Examples:

```text
get_my_profile
get_subject_hierarchy
record_learning_activity
finalize_quiz_attempt
```

Existing RPC names must be preserved unless there is a compelling compatibility reason to change them.

---

## 6. Database Design Rules

1. Every table must have a primary key.
2. Every foreign key must reference a valid parent table.
3. Required business fields must use `NOT NULL`.
4. Use check constraints for fixed status values and numeric boundaries.
5. Use `created_at` and `updated_at` where record history matters.
6. Use `timestamptz`, not plain `timestamp`, for user and system activity.
7. Store all timestamps in UTC.
8. Avoid storing derived totals when they can be computed safely, unless performance requires materialization.
9. Avoid JSONB for highly structured relational data.
10. JSONB may be used for flexible metadata, preferences, or non-relational attributes.
11. Do not use text fields for relationships when a foreign key is appropriate.
12. Do not delete historical quiz attempts, learning activity, or entitlement records without an approved archival policy.
13. Use soft-status transitions where auditability is important.
14. Do not rename or drop an existing production column without a migration and compatibility review.
15. New migrations must be idempotent where practical.

---

## 7. PostgreSQL Function and RPC Rules

Every RPC must:

1. Have a clear business purpose.
2. Use explicit parameter names prefixed with `p_`.
3. Declare the return type explicitly.
4. Validate `auth.uid()` when the function is user-specific.
5. Never trust a user-supplied `user_id` when `auth.uid()` can be used.
6. Prevent one user from reading or changing another user's records.
7. Use `SECURITY DEFINER` only when required.
8. When using `SECURITY DEFINER`, set a safe search path.

Required pattern:

```sql
CREATE OR REPLACE FUNCTION public.example_rpc(
    p_subject_id integer
)
RETURNS TABLE (
    subject_id integer,
    subject_title text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    RETURN QUERY
    SELECT s.id, s.title
    FROM public.subjects s
    WHERE s.id = p_subject_id
      AND s.is_active = true;
END;
$$;
```

9. Revoke broad execution access where needed.
10. Grant execution only to intended roles.

Example:

```sql
REVOKE ALL ON FUNCTION public.example_rpc(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.example_rpc(integer) TO authenticated;
```

11. Use `RAISE EXCEPTION` for invalid or unauthorized operations.
12. Avoid dynamic SQL unless absolutely necessary.
13. Do not expose sensitive fields.
14. Do not return `correct_option` before the quiz rules allow it.
15. Do not overwrite existing working RPCs without first reviewing their signatures and frontend dependencies.
16. Each RPC must include verification SQL in the corresponding migration or test file.
17. Each RPC should be small enough to test independently.
18. Complex repeated logic should be moved into a helper function or view.

---

## 8. Authentication and Authorization Rules

1. Supabase Auth is the only source of authenticated user identity.
2. Use `auth.uid()` for the current user.
3. The frontend must never set or modify:

   - `user_id`
   - `role`
   - `status`
   - `subscription_plan`
   - entitlement status
   - quiz score
   - answer correctness
   - pass/fail result

4. User registration may submit profile details, but privileged defaults must be assigned by the database.
5. Email confirmation must be respected before activating access where configured.
6. Administrative functions must verify the user's role server-side.
7. Never rely only on hidden buttons or frontend conditions for authorization.
8. Service-role keys must never be exposed in browser code.
9. Supabase anonymous keys may be used in the frontend only as intended with RLS enabled.
10. Passwords must never be logged, stored in custom tables, or committed to GitHub.

---

## 9. Row-Level Security Rules

1. RLS must remain enabled on user-owned and sensitive tables.
2. Users may read or update only their own profile, progress, activity, attempts, carts, and entitlements where appropriate.
3. Public academic catalogue data may be readable by authenticated or anonymous users only when intentionally approved.
4. Premium resources must require an active entitlement or approved subscription.
5. RLS policies must not use permissive conditions such as `true` on sensitive tables.
6. RLS policies must be documented in migration files.
7. Test policies with at least:

   - anonymous user
   - authenticated regular user
   - second authenticated user
   - admin user

8. RPCs must not be used to bypass RLS without explicit ownership and authorization validation.

---

## 10. Quiz Engine Rules

1. Preserve the existing quiz engine unless a verified issue requires modification.
2. Current modes are:

```text
practice
mock
proctored_mock
```

3. Current feedback modes are:

```text
immediate
final_only
```

4. Question selection must respect:

   - active status
   - subject
   - module, chapter, or topic filter where applicable
   - quiz mode configuration
   - question count
   - entitlement or demo rules

5. The frontend must not receive the correct answer before permitted.
6. Scoring must be calculated in the database.
7. Attempt ownership must always be verified with `auth.uid()`.
8. A completed attempt must not be silently reopened.
9. Finalization must be idempotent.
10. Duplicate question allocation within one attempt must be prevented.
11. `answered_count`, `correct_answers`, `wrong_answers`, `score`, `percentage`, and `passed` must remain internally consistent.
12. Mock and proctored mock results must follow final-only feedback unless explicitly configured otherwise.
13. Time limits must be enforced server-side where possible and validated during finalization.
14. Quiz review must not expose restricted answers before completion.
15. Existing RPCs to preserve and audit:

```text
start_quiz_attempt
get_attempt_questions
submit_quiz_answer
evaluate_quiz_answer
finalize_quiz_attempt
finalize_quiz_attempt_with_answers
get_my_quiz_attempts
```

---

## 11. Learning and Progress Rules

1. Progress is tracked at topic level.
2. Valid progress statuses are:

```text
not_started
in_progress
completed
```

3. Completion percentage must remain between 0 and 100.
4. A completed topic should normally have:

```text
status = completed
completion_percentage = 100
completed_at IS NOT NULL
```

5. Learning time must never decrease.
6. Progress updates must be linked to the authenticated user.
7. Activity records should be written for meaningful events.
8. Supported activity types must remain consistent with database constraints.
9. Resume-learning logic should prioritize the most recently accessed incomplete topic.
10. Analytics must be derived from reliable activity and progress data.

---

## 12. Entitlement and Premium Content Rules

1. Access to premium subjects or resources must be validated server-side.
2. Valid entitlement status must be checked against:

   - `status = active`
   - `valid_from <= now()`
   - `valid_until IS NULL OR valid_until >= now()`

3. Demo access must respect the subject's demo settings and question limit.
4. The frontend must not decide entitlement eligibility.
5. Entitlement grants and revocations must be auditable.
6. Payments must not automatically grant access until the payment state is verified.
7. Cart prices must be validated against server-side subject pricing.
8. Never trust `unit_price` received from the browser.

---

## 13. Frontend Rules

1. Use semantic HTML5.
2. Keep HTML, CSS, and JavaScript separate for new or materially refactored pages.
3. Existing inline code may be migrated gradually.
4. Do not use inline `onclick` handlers in new code.
5. Use `addEventListener`.
6. Avoid global variables.
7. Wrap page initialization in `DOMContentLoaded`.
8. Verify that every DOM element exists before reading or updating it.
9. Use consistent element IDs and data attributes.
10. All user input must be validated in the browser for usability and again in the database for security.
11. Never hardcode secrets, service-role keys, passwords, or private API keys.
12. Centralize Supabase client initialization.
13. Centralize environment-dependent configuration.
14. Display clear loading, success, empty, and error states.
15. Prevent duplicate form submission.
16. Disable buttons while network requests are in progress.
17. Handle expired sessions and redirect appropriately.
18. Escape or safely render user-provided content.
19. Avoid injecting untrusted HTML.
20. Use accessible labels, keyboard navigation, and meaningful button text.
21. Responsive behavior must support desktop, tablet, and mobile.
22. Do not redesign unrelated pages while implementing a focused task.
23. Preserve the existing visual identity unless the task explicitly includes UI redesign.

---

## 14. JavaScript Rules

1. Use `const` by default and `let` only when reassignment is required.
2. Do not use `var`.
3. Use `async/await` for asynchronous operations.
4. Wrap Supabase and network calls in `try/catch`.
5. Check both returned data and errors.
6. Use descriptive function names.
7. Keep functions focused on one responsibility.
8. Avoid deeply nested callbacks and conditions.
9. Use modules where the frontend structure supports them.
10. Log useful development errors without exposing sensitive information.
11. Remove temporary debugging logs before production unless intentionally retained.
12. Do not suppress errors silently.
13. Keep API/RPC names in a centralized service layer where practical.
14. Validate RPC response shapes before rendering.

---

## 15. CSS and Tailwind Rules

1. Reuse consistent spacing, typography, border-radius, and component patterns.
2. Avoid unnecessary custom CSS when Tailwind utilities are sufficient.
3. Do not repeat large Tailwind class groups across many pages; extract reusable components where practical.
4. Maintain readable contrast.
5. Do not use arbitrary colors without documenting the design palette.
6. Avoid fixed-width layouts that break on mobile.
7. Keep animation subtle and purposeful.
8. Do not use visual styling as the sole indicator of status or error.

---

## 16. Error Handling Rules

1. User-facing errors must be understandable and actionable.
2. Internal database errors must not be exposed verbatim to end users.
3. Log technical details only in appropriate development or monitoring channels.
4. Authentication failures must redirect or prompt re-login safely.
5. Invalid input must be rejected before executing business logic.
6. Duplicate operations should return a safe, clear result.
7. RPC errors must use consistent messages.
8. Failed writes must not leave partial or inconsistent records.
9. Use transactions for multi-step operations that must succeed or fail together.

---

## 17. Testing Rules

Every feature must include relevant tests.

Minimum verification categories:

- SQL compilation
- Function signature
- Authentication
- Authorization
- Valid input
- Invalid input
- Ownership check
- Empty data
- Duplicate action
- Boundary values
- Regression impact
- Frontend success state
- Frontend error state
- Mobile layout where applicable

For user-owned functionality, test with two different user accounts to confirm isolation.

For quiz functions, test:

- no available questions
- fewer questions than requested
- duplicate submission
- expired attempt
- completed attempt
- unauthorized attempt
- immediate feedback
- final-only feedback
- score and percentage consistency

Do not mark a feature complete until verification steps pass.

---

## 18. Migration Rules

1. One migration should represent one logical change.
2. Migration names must describe the change.
3. Never edit an already deployed production migration.
4. Create a new corrective migration instead.
5. Include safe guards such as `IF EXISTS` or `IF NOT EXISTS` where appropriate.
6. Include rollback SQL in documentation for high-risk changes.
7. Back up affected data before destructive changes.
8. Never drop a table or column without explicit approval.
9. Review dependencies before replacing functions.
10. Verify migrations in a non-production environment first.

---

## 19. Git and Commit Rules

Use clear, focused commits.

Recommended commit format:

```text
type(scope): concise description
```

Examples:

```text
feat(rpc): add subject hierarchy endpoint
fix(quiz): prevent duplicate answer submission
refactor(frontend): separate dashboard scripts
docs(context): update project roadmap
test(progress): add topic completion verification
```

Allowed types:

```text
feat
fix
refactor
docs
test
chore
security
migration
```

Do not combine unrelated changes in one commit.

Do not commit:

- `.env`
- private keys
- passwords
- database credentials
- service-role keys
- personal data exports
- production backups
- temporary debug files

---

## 20. Environment and Secret Rules

Use environment variables for:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
OPENAI_API_KEY
SMTP credentials
other private integration keys
```

Only browser-safe values may be exposed through frontend environment variables.

Never expose:

```text
SUPABASE_SERVICE_ROLE_KEY
database password
OpenAI secret key
SMTP password
private tokens
```

Provide a `.env.example` containing variable names only.

---

## 21. Documentation Rules

Each major feature should document:

- purpose
- business requirement
- affected tables
- affected RPCs
- frontend impact
- security impact
- execution order
- verification
- rollback
- version history

Update the following when relevant:

```text
README.md
PROJECT_CONTEXT.md
CODING_RULES.md
CHANGELOG.md
docs/
```

Do not leave major architectural decisions only inside chat conversations.

---

## 22. AI Assistant Rules

Any AI coding assistant working on InsureGPTE must:

1. Read `PROJECT_CONTEXT.md` and `CODING_RULES.md` before making changes.
2. Inspect the repository before proposing new files or objects.
3. Preserve existing function signatures used by the frontend.
4. Avoid inventing tables, columns, policies, or RPCs.
5. Verify all names against the schema.
6. State assumptions explicitly.
7. Make the smallest safe change required.
8. Avoid broad rewrites unless requested.
9. Provide a summary of files changed.
10. Provide verification steps.
11. Never claim that code was tested unless tests were actually run.
12. Never expose or request secrets unnecessarily.
13. Stop and ask for clarification where a change could destroy data or break compatibility.
14. Keep the Version 1.0 scope frozen unless explicitly authorized.

Recommended instruction for Codex:

```text
Before making changes, read PROJECT_CONTEXT.md and CODING_RULES.md.
Inspect the current repository and database schema.
Do not create duplicate objects or change existing working RPC signatures.
Make only the smallest safe changes required.
Run available checks and clearly report what passed, failed, or could not be tested.
```

---

## 23. Definition of Done

A feature is complete only when:

- code is implemented
- database changes are version controlled
- security checks are included
- tests or verification steps pass
- frontend behavior is confirmed
- documentation is updated
- no secrets are committed
- no existing feature is unintentionally broken
- commit is pushed to GitHub

---

## 24. Current Priority

The current priority order is:

1. Complete and verify the RPC layer.
2. Integrate RPCs with the frontend.
3. Refactor inline JavaScript and CSS gradually.
4. Complete dashboard and learning flows.
5. Complete analytics and recommendation logic.
6. Populate and validate educational content.
7. Perform end-to-end testing.
8. Deploy Version 1.0.

Do not start lower-priority enhancements before the current phase is stable.

---

## 25. Final Rule

When there is a conflict between speed and correctness:

> Choose correctness, security, traceability, and maintainability.

When there is a conflict between a new idea and the frozen Version 1.0 scope:

> Preserve the approved scope and document the new idea for a future version.
