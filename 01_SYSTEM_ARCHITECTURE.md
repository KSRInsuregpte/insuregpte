# InsureGPTE System Architecture

**Document:** 01_SYSTEM_ARCHITECTURE.md  
**Version:** 1.3  
**Status:** Approved — Architecture Frozen  
**Approval Date:** 2026-07-20  
**Project Owner:** Sundararajan Desikan  
**Platform:** InsureGPTE  
**Primary Stack:** HTML, Tailwind CSS, JavaScript, Supabase, PostgreSQL, Vercel  
**Repository:** GitHub  
**Implementation Assistant:** ChatGPT Codex  
**Architecture and Review:** ChatGPT  

---

## 1. Purpose

This document defines the approved system architecture for InsureGPTE Version 1.0. It is the master blueprint for product development, database design, RPC development, frontend implementation, security, testing, deployment, and maintenance.

All implementation must remain consistent with:

- `PROJECT_CONTEXT.md`
- `CODING_RULES.md`
- `PROJECT_GOVERNANCE.md`
- this document

---

## 2. Product Definition

InsureGPTE is an insurance education, learning, revision, testing, and examination-preparation platform.

Primary users:

- insurance students;
- insurance professionals;
- insurance brokers;
- reinsurance professionals;
- surveyors and loss assessors;
- examination candidates;
- corporate learners;
- administrators and content managers.

Version 1.0 is not an insurance CRM, policy administration system, claims platform, reinsurance placement system, recruitment platform, ERP, or general accounting system.

---

## 3. Architecture Principles

1. GitHub is the single source of truth.
2. Supabase PostgreSQL is the authoritative data store.
3. Supabase Auth is the only authentication authority.
4. The frontend must not control privileged business fields.
5. Business logic must be enforced server-side.
6. User-specific operations must validate `auth.uid()`.
7. Sensitive data must not be exposed to the browser.
8. Correct answers must not be exposed before permitted.
9. Premium access must be validated server-side.
10. Existing working RPC signatures must be preserved unless formally approved.
11. Feature delivery sequence:

```text
Database
→ RPC
→ Frontend
→ Testing
→ Deployment
```

---

## 4. High-Level Architecture

```text
User Browser
    |
    v
Vercel Frontend
    |
    v
Supabase JavaScript Client
    |
    +--------------------+
    |                    |
    v                    v
Supabase Auth       Supabase RPC Layer
                         |
                         v
                  PostgreSQL Database
                         |
          +--------------+--------------+
          |              |              |
          v              v              v
     Learning Data   Quiz Data      Entitlement Data
```

---

## 5. Architecture Layers

### 5.1 Presentation Layer

Technology:

- HTML5
- Tailwind CSS
- Vanilla JavaScript

Responsibilities:

- render pages;
- capture user input;
- call approved RPCs;
- manage navigation and session state;
- show loading, success, empty, and error states;
- support responsive and accessible interaction.

The frontend must not calculate authoritative scores, assign roles, grant entitlement, determine answer correctness, or contain private keys.

### 5.2 Authentication Layer

Technology:

- Supabase Auth
- Email/password login
- email confirmation by OTP;
- standard Supabase mobile confirmation by SMS OTP;
- Cloudflare Turnstile for Auth bot protection.

Supabase Auth is the Version 1.0 identity provider. The application user UUID
must remain stable and portable so a future identity provider or database
migration does not require rewriting user-owned learning, quiz, progress, or
entitlement records.

Authoritative user identity:

```sql
auth.uid()
```

Account lifecycle:

```text
verification_pending
→ active
→ suspended
→ closed
```

Defaults:

```text
role = user
status = verification_pending
subscription_plan = free
```

Protected registration policy:

- all profile fields and a referral source are required;
- at least one active subject must be selected;
- the browser and the Before User Created Auth hook validate registration;
- the trusted profile trigger repeats critical validation as a backstop;
- new protected accounts remain `verification_pending` until the email and the
  registered mobile number are both confirmed by Supabase Auth;
- pending profiles cannot use protected table or RPC operations;
- OTP values and provider secrets are never stored in application tables.

Session-concurrency policy:

- one active browser page is permitted per user across tabs, browsers, and
  devices;
- the first active page remains in control by default;
- a later login must stop before the dashboard and offer two explicit choices:
  cancel the new login or transfer control with **Use this login**;
- transferring control disables the earlier page and revokes its renewable Auth
  session; sharing one Supabase `session_id` does not permit two usable pages;
- explicit Logout ends the account's active lease and all Auth sessions;
- session enforcement must be server-side for protected operations and must not
  rely only on frontend navigation or hidden controls.

### 5.3 Service Layer

Technology:

- PostgreSQL functions;
- Supabase RPC;
- helper functions;
- approved views.

Responsibilities:

- user-safe data access;
- learning-resource access;
- progress updates;
- quiz lifecycle and scoring;
- analytics;
- entitlement validation;
- dashboard aggregation.

### 5.4 Data Layer

Technology:

- PostgreSQL through Supabase.

Primary domains:

- users and profiles;
- academic hierarchy;
- learning resources;
- flashcards;
- questions;
- quiz attempts;
- progress;
- activity;
- carts;
- entitlements.

### 5.5 Hosting and Delivery

Technology:

- GitHub;
- Vercel;
- Supabase;
- Namecheap Private Email.

---

## 6. Core Modules

### 6.1 Authentication and Profile

Key objects:

- `auth.users`
- `public.profiles`
- `save_user_profile`
- `activate_verified_user`
- `handle_new_user`
- `auto_approve_user`

Functions:

- registration;
- email verification;
- login and logout;
- profile creation;
- profile update;
- account-state enforcement.

Security rule: the browser cannot set role, status, plan, or user ID.

### 6.2 Academic Catalogue

Hierarchy:

```text
Qualification Level
→ Exam Authority
→ Training Programme
→ Programme Section
→ Subject
→ Module
→ Chapter
→ Topic
```

Key tables:

- `qualification_levels`
- `exam_authorities`
- `training_programmes`
- `programme_sections`
- `subjects`
- `subject_modules`
- `subject_chapters`
- `subject_topics`

### 6.3 Learning Content

Key tables:

- `learning_resource_types`
- `learning_resources`
- `flashcards`

Functions:

- retrieve topic resources;
- display notes, links, files, and videos;
- review flashcards;
- control premium access;
- show estimated study time and exam relevance.

### 6.4 Progress and Activity

Key tables:

- `user_topic_progress`
- `user_learning_activity`

Topic states:

```text
not_started
in_progress
completed
```

Functions:

- start and resume topics;
- record time spent;
- update completion;
- log meaningful activity;
- calculate progress.

### 6.5 Quiz and Examination

Key tables:

- `questions`
- `quiz_mode_config`
- `quiz_attempts`
- `quiz_attempt_questions`

Existing RPCs:

- `start_quiz_attempt`
- `get_attempt_questions`
- `submit_quiz_answer`
- `evaluate_quiz_answer`
- `finalize_quiz_attempt`
- `finalize_quiz_attempt_with_answers`
- `get_my_quiz_attempts`

Modes:

```text
practice
mock
proctored_mock
```

Feedback:

```text
immediate
final_only
```

Rules:

- attempt ownership must be verified;
- answers are scored server-side;
- correct answers are hidden until permitted;
- finalization is idempotent;
- completed attempts are protected;
- duplicate question allocation is prevented;
- totals remain internally consistent.

### 6.6 Dashboard and Analytics

Purpose:

- entitled subjects;
- resume learning;
- topic and subject progress;
- recent activity;
- recent attempts;
- weak topics;
- recommended topics;
- readiness and performance trends.

Planned RPCs include:

- `get_student_dashboard`
- `get_subject_progress`
- `get_module_progress`
- `get_chapter_progress`
- `get_recent_activity`
- `get_weak_topics`
- `get_recommended_topics`
- `get_exam_readiness`
- `get_performance_trend`

### 6.7 Commerce and Entitlement

Key tables:

- `carts`
- `cart_items`
- `user_entitlements`

Access types:

```text
purchase
complimentary
promotional
subscription
admin_grant
```

Statuses:

```text
active
expired
revoked
pending
```

Valid-access rule:

```text
status = active
AND valid_from <= now()
AND (valid_until IS NULL OR valid_until >= now())
```

The browser must never grant access or determine the authoritative price.

### 6.8 Administration

Version 1.0 scope:

- manage academic hierarchy;
- manage subjects;
- manage learning resources;
- manage flashcards;
- manage questions;
- manage demo settings and price;
- manage entitlement;
- manage account status;
- review quiz activity;
- manage active/inactive content.

Administrative authorization must be checked server-side.

---

## 7. User Roles

Approved roles:

```text
user
admin
instructor
moderator
```

### User

Can access own profile, entitled or demo content, quizzes, progress, and attempt history.

### Admin

Can manage users, content, academic structure, entitlement, and reports.

### Instructor

May create or edit assigned learning and question content.

### Moderator

May review and approve educational and question content.

---

## 8. Frontend Page Architecture

### `index.html`

Combined page for:

- registration;
- email-verification guidance;
- login;
- account messages;
- future password recovery.

No separate `register.html` is required.

### `dashboard.html`

Authenticated learner landing page for:

- subject catalogue;
- entitled subjects;
- resume learning;
- progress;
- recent attempts;
- navigation.

### `test.html`

Quiz page for:

- instructions;
- question rendering;
- option selection;
- navigation;
- timer;
- answer submission;
- finalization;
- result or review.

Future pages may include:

- `subject.html`
- `learning.html`
- `flashcards.html`
- `quiz-history.html`
- `quiz-review.html`
- `profile.html`
- `cart.html`
- `admin-dashboard.html`

---

## 9. Primary User Flows

### Registration

```text
Open index.html
→ Register
→ Browser validates every required field and at least one subject
→ Cloudflare Turnstile challenge
→ Before User Created hook validates the request server-side
→ Supabase creates Auth user and trusted pending profile
→ Enter email OTP
→ Enter mobile SMS OTP
→ Database confirms both Auth verifications and activates the profile
→ Dashboard
```

### Login

```text
Open index.html
→ Enter credentials
→ Supabase validates
→ Claim the short-lived active-client lease
→ No existing active page: enter dashboard
→ Existing active page: show Cancel / Use this login confirmation
→ Cancel: end the new local login; first page remains active
→ Use this login: transfer lease; disable first page; enter dashboard
```

### Learning

```text
Dashboard
→ Subject
→ Module
→ Chapter
→ Topic
→ Learning resources
→ Flashcards
→ Progress updated
→ Activity recorded
```

### Practice Quiz

```text
Choose scope
→ Start attempt
→ Questions allocated
→ Submit answers
→ Immediate feedback where allowed
→ Finalize
→ Store result
```

### Mock Test

```text
Read instructions
→ Start timed attempt
→ No immediate feedback
→ Submit or auto-submit
→ Finalize
→ Show final result and review
```

### Entitlement

```text
Select paid subject
→ Add to cart
→ Server validates price
→ Payment verified
→ Entitlement created
→ Access activated
```

---

## 10. Data Ownership

User-owned data:

- profiles;
- quiz attempts and answers;
- progress;
- activity;
- carts;
- entitlements.

Catalogue data:

- qualifications;
- authorities;
- programmes;
- sections;
- subjects;
- modules;
- chapters;
- topics;
- resource types.

Content data:

- learning resources;
- flashcards;
- questions.

Ownership must be enforced through RLS and RPC checks.

---

## 11. Security Architecture

### Identity

The configured identity provider is the sole authentication authority.
Supabase Auth is the Version 1.0 provider, and user-specific functions use
`auth.uid()`. Application data must continue to use a stable UUID so the
identity provider can be replaced through a controlled migration.

New public registration is protected by CAPTCHA and a Before User Created Auth
hook. Email and mobile OTP generation and verification remain within Supabase
Auth. Application tables store only verification timestamps and the normalized
registered mobile number; they never store OTP values.

### Session Concurrency

- only one active browser page is allowed per user;
- the first active page is authoritative until explicit logout, lease expiry,
  or an approved **Use this login** transfer;
- a later authentication cannot enter the dashboard automatically;
- a displaced page must be denied protected table and RPC access even while a
  previously issued access token has not yet expired;
- duplicate tabs are blocked by the shared frontend controller, while the
  database lease protects cross-browser and cross-device access;
- session checks must use trusted server-side session state;
- session-control changes require rollback SQL or a documented platform-setting
  rollback, Auth testing, cross-browser testing, and active-quiz testing.

### Authorization

Based on:

- identity;
- account status;
- role;
- entitlement;
- resource status;
- quiz state.

### RLS

RLS must remain enabled on sensitive and user-owned tables.

### Secrets

Never expose:

- Supabase service-role key;
- database password;
- SMTP password;
- OpenAI secret key;
- private tokens.

### Quiz Security

- answers remain server-side until allowed;
- scoring is server-side;
- ownership is checked;
- completed attempts are protected;
- review access follows feedback mode.

---

## 12. RPC Architecture

### Pack 1 — User and Academic Services

- `get_my_profile`
- `get_my_entitlements`
- `get_subject_catalogue`
- `get_subject_hierarchy`
- `get_modules_by_subject`
- `get_chapters_by_module`
- `get_topics_by_chapter`
- `search_subjects`

### Pack 2 — Learning Services

- `get_learning_resources`
- `get_flashcards`
- `get_topic_details`
- `record_learning_activity`
- `get_resume_learning`
- `get_recent_activity`
- `get_topic_completion`
- `get_learning_statistics`

### Pack 3 — Dashboard and Analytics

- `get_student_dashboard`
- `get_subject_progress`
- `get_module_progress`
- `get_chapter_progress`
- `get_weak_topics`
- `get_recommended_topics`
- `get_learning_streak`
- `get_overall_statistics`

### Pack 4 — Quiz Reporting

- `get_attempt_summary`
- `get_attempt_review`
- `get_question_analysis`
- `get_subject_statistics`
- `get_exam_readiness`
- `get_mock_test_history`
- `get_rank_summary`
- `get_performance_trend`

Existing quiz RPCs must be preserved.

---

## 13. External Integrations

### Supabase

Used for Auth, PostgreSQL, RPC, RLS, and optional storage.

### Vercel

Used for frontend hosting, deployment, domain routing, and environment configuration.

### Namecheap Private Email

Used for SMTP and branded email support.

### OpenAI

Potential future uses:

- AI tutor;
- explanation assistance;
- content-authoring support;
- learner recommendations.

AI-produced educational content must be reviewed before being treated as authoritative.

---

## 14. Performance Principles

- index foreign keys and frequent filters;
- paginate large result sets;
- avoid unnecessary columns;
- aggregate dashboard data through RPCs;
- filter server-side;
- avoid loading all questions into the browser;
- optimize based on measured slow queries.

---

## 15. Audit and Observability

Version 1.0 should record:

- registration and activation;
- learning activity;
- progress;
- quiz starts and completions;
- entitlement grants and revocations;
- important administrative changes.

Production logging must not expose secrets or unnecessary personal data.

---

## 16. Deployment Architecture

```text
Developer / Codex
→ GitHub branch
→ Review
→ Merge to main
→ Vercel deployment
→ Supabase migrations
→ Smoke testing
→ Production verification
```

Required controls:

- source backup;
- database backup;
- migration order;
- environment verification;
- authentication test;
- quiz test;
- entitlement test;
- rollback plan.

---

## 17. Environments

Recommended:

```text
Development
Testing / Staging
Production
```

Each environment should have separate configuration and secrets.

---

## 18. Testing Architecture

Testing categories:

- SQL;
- RPC integration;
- Auth;
- authorization and RLS;
- frontend;
- quiz;
- progress;
- entitlement;
- cross-user isolation;
- responsive layout;
- regression;
- user acceptance;
- production smoke tests.

---

## 19. Version 1.0 Scope Freeze

### Included

- authentication and profile;
- academic hierarchy;
- catalogue;
- learning resources;
- flashcards;
- quizzes and mock tests;
- progress and activity;
- dashboard and analytics;
- cart and entitlement;
- basic administration;
- production deployment.

### Deferred

- native mobile apps;
- live classes;
- social learning;
- full discussion forum;
- enterprise LMS integrations;
- advanced subscription billing;
- advanced AI tutoring;
- external certification;
- large-scale proctoring infrastructure.

---

## 20. Main Risks

1. Direct frontend table access.
2. Weak RLS.
3. Duplicate RPCs.
4. Inconsistent hierarchy.
5. Premature answer exposure.
6. Browser-controlled pricing.
7. Large inline scripts.
8. Poor migration discipline.
9. Missing tests.
10. Scope expansion before launch.

---

## 21. Approved Development Sequence

```text
1. Freeze architecture
2. Review database
3. Complete RPC catalogue
4. Implement missing RPCs
5. Integrate frontend
6. Refactor inline CSS and JavaScript gradually
7. Populate and validate content
8. Complete testing
9. Deploy
10. Monitor and stabilize
```

---

## 22. Architecture Approval

The project owner approved and froze this document on 2026-07-19, including:

- Version 1.0 scope;
- module architecture;
- database hierarchy;
- RPC categories;
- frontend page flow;
- roles and security model;
- included and deferred features.

Implementation may now proceed through the approved development sequence.
Material architecture changes still require the change-control process below.

---

## 23. Change Control

Any architecture change must document:

- requested change;
- business reason;
- affected modules;
- database impact;
- security impact;
- migration impact;
- testing impact;
- release impact;
- approval decision.

### Approved change record — 2026-07-19

- **Requested change:** prohibit concurrent authenticated sessions for one user
  account while keeping logout as an explicit user action.
- **Business reason:** reduce account sharing and protect learning and practice
  test integrity.
- **Affected modules:** authentication, protected RPCs, frontend session
  handling, testing, and deployment configuration.
- **Database impact:** none at architecture-freeze stage; implementation impact
  depends on the selected enforcement mechanism.
- **Security impact:** authentication/session behavior will change when
  enforcement is deployed.
- **Migration impact:** implementation must be version controlled and reversible.
- **Testing impact:** same-browser, cross-browser, cross-device, active-quiz,
  logout, expiry, and recovery cases are mandatory.
- **Release impact:** deploy to staging before production.
- **Approval decision:** approved by the project owner.

### Implementation status update — 2026-07-19

- The Supabase project is on the Free plan, so the managed single-session
  switch is unavailable.
- Refresh-token replay detection is enabled with a 10-second reuse interval.
- Time-box and inactivity limits remain disabled, and JWT expiry is 3,600
  seconds.
- A Free-plan-compatible PostgREST pre-request guard, frontend session
  handling, verification SQL, and rollback have been prepared in the
  repository. They are not active until the migration and frontend are
  deployed and the mandatory browser tests pass.
- The guard covers PostgREST table and RPC requests. Any future protected
  Storage or Realtime feature must add equivalent session enforcement before
  release.

### Approved refinement and implementation — 2026-07-20

- **Requested refinement:** a later login must not automatically replace the
  first page. It must stop before the dashboard and ask whether to cancel or
  explicitly transfer control. Duplicate tabs must also be unusable.
- **Approval decision:** approved by the project owner following Chrome and
  Edge runtime testing.
- **Database impact:** add one short-lived `active_client_leases` control row per
  active user plus three narrowly granted RPCs. This is not a second identity or
  authentication store: Supabase Auth remains the only identity authority and
  no password, token, email, or profile data is stored in the lease table.
- **Frontend impact:** add one shared session controller used by login,
  dashboard, and quiz pages for the client header, duplicate-tab control,
  confirmation, heartbeat, displacement, and global logout.
- **Deployment impact:** apply the compatibility migration, deploy all updated
  pages and the shared controller, then apply strict enforcement. Each database
  stage has a matching rollback.
- **Detection behavior:** protected writes are denied immediately by the
  database. An already displayed displaced page is covered and redirected when
  its ten-second heartbeat or an activity/focus check detects the transfer.
- **Recovery behavior:** a browser closed without Logout releases control after
  the 90-second lease expires; the user may also explicitly transfer control
  sooner.
- **Implementation status:** repository implementation and static verification
  are complete; production SQL deployment and manual browser verification are
  still required.

### Approved protected-registration implementation — 2026-07-21

- **Requested change:** prevent incomplete/direct automated registration,
  validate all registration fields, require at least one subject, record the
  referral source, and verify both email and mobile ownership by OTP.
- **Business reason:** protect learner identity quality, SMS/email reputation,
  platform access, and examination integrity before public registration is
  reopened.
- **Database impact:** extend `profiles` with registration source, trusted
  validation version, and email/mobile verification timestamps; add one Auth
  hook function; harden existing lifecycle functions without changing their
  signatures; extend the existing PostgREST pre-request guard with active-profile
  enforcement. The existing unique mobile constraint is reused.
- **Frontend impact:** replace inline registration behavior with shared,
  testable validation and Auth flow scripts; add field guidance, CAPTCHA, email
  OTP, and mobile OTP views.
- **Security impact:** incomplete Auth requests are rejected before creation and
  again by the profile trigger; new accounts cannot access protected data until
  both OTP checks pass. OTP codes and provider secrets are not stored by the
  application.
- **External configuration:** Turnstile keys, an SMS provider, the email OTP
  template, the Auth hook selection, and the Auth password policy must be
  configured in their respective dashboards before signup is reopened.
- **Approval decision:** approved by the project owner on 2026-07-21.
- **Implementation status:** repository SQL, frontend, rollback, audit,
  verification, tests, and deployment guide are complete; production migration
  and provider configuration are pending owner execution.

---

## 24. Next Document

After approval, proceed to:

```text
02_DATABASE_DESIGN.md
```

That document will describe every table, relationship, constraint, recommended index, security rule, and integrity requirement.
