# CHANGELOG

All notable changes to the InsureGPTE project will be documented in this file.

This project follows Semantic Versioning (SemVer).

---

## [1.0.0] - In Development

### Added

- Initial project architecture
- Supabase authentication
- Email verification
- User registration
- User login
- User dashboard
- User profile management
- Qualification hierarchy
- Exam authority hierarchy
- Training programme hierarchy
- Programme sections
- Subjects
- Modules
- Chapters
- Topics
- Learning resources
- Flashcards
- Quiz engine
- Quiz attempt engine
- Learning progress
- User activity tracking
- Shopping cart
- User entitlements
- Public categorized subject catalogue
- Subject learning-path overview
- Server-priced learner cart
- Ten-question advanced-difficulty demo mode
- Trial regulatory source register for official syllabus, timetable, centre,
  withdrawal, and subject-amendment governance
- Privacy-safe, read-only live hierarchy and examination-object audit used to
  prevent duplicate academic mappings, session tables, and RPCs
- Guarded regulatory metadata mapping that reuses the academic hierarchy,
  keeps IC02 inactive pending content review, and blocks withdrawn subjects
- Authenticated `get_exam_information` RPC for current verified examination
  schedules, centre lists, and language notices
- Privacy-safe, read-only audit for live admin roles, management/payment object
  conflicts, question difficulty distribution, table privileges, and commerce
  aggregates
- Administrator-only audit history, subject/question/user-activation/exam-
  information RPCs, and hidden `admin-dashboard.html`
- Downloadable administrator CSV formats and an illustrated Excel guide for
  existing-user status, academic hierarchy, subjects, learning content,
  question-bank data, official exam information, and non-payment entitlements
- Atomic `admin_bulk_import(text,jsonb)` coordination through the existing
  and dedicated guarded administrator save RPCs, without new data tables
- Existing examination-information metadata now accepts general official
  notices in addition to schedules, centre lists, amendments, and prior types
- Expanded the existing administrator audit entity-type constraint so every
  approved academic, learning-content, examination, and non-payment bulk
  import can retain its required per-record audit history
- Privacy-safe, read-only safety-system object audit covering existing Auth
  audit logs, active-client leases, administrator audit history, potential
  incident/warning/notification conflicts, extension availability, triggers,
  constraints, privileges, and aggregate sessions claimed over 48 hours
- Administrator-reviewed Security & Alerts foundation with privacy-safe
  events, three-warning enforcement cases, critical-event suspension,
  restoration, learner dashboard notices, and a service-side email outbox
- Automatic informational registration alerts and administrator-triggered
  scans that reuse active-client lease claim times for the 48-hour threshold
- Service-role-only integration boundaries for approved provider safety
  monitors and future email delivery workers
- PROJECT_CONTEXT.md
- CODING_RULES.md

### Changed

- Froze Architecture Version 1.6 with eight qualification levels,
  five III programmes, three NIA broker programmes, four programme categories,
  nine programme-section codes, and four subject-category dropdown values
- Consolidated the former standalone NIA Life Broker programme into Direct
  Broker while preserving linked subjects and examination information
- Added III Specialised Diploma and Surveyor programmes and database-enforced
  hierarchy vocabulary checks
- Restricted Admin, CSV upload, and database subject categories to the four
  approved dropdown values
- Clarified Direct Broker as
  `Direct Broker – General, Life and Health Training` with the description
  `General, Life and Health Training`
- Filtered Admin programme-section selectors by the selected programme and
  safely remapped legacy same-code sections instead of submitting a section
  owned by another programme
- Added an explicit Admin deployment warning and save guard when the preview
  database still exposes the previous qualification, programme, or section
  configuration
- Added a guarded data repair for subjects and examination information linked
  to a programme section owned by another programme
- Added the reviewed, record-preserving mapping of 20 legacy III Optional
  Credit subjects into Licentiate, Associate, and Fellowship destinations;
  subject IDs, activation states, and dependent records remain unchanged

- Database normalized into hierarchical academic structure
- Learner safety notices now refresh across every authenticated catalogue,
  subject, cart, dashboard, and practice page instead of appearing only on the
  dashboard.
- Suspended or inactive accounts are signed out locally and returned to the
  login page with a clear restricted-access explanation as soon as a protected
  request or active-session heartbeat detects the restriction.
- Security review, warning, suspension, and restoration decisions now use an
  accessible on-page administrator form instead of blocking browser prompt
  and confirmation dialogs.
- Suspended learners now receive an immediately blocking explanation for eight
  seconds before local sign-out, giving enough time to read the reason without
  restoring any protected access.
- Restoration continues to queue the existing audited learner email; actual
  inbox delivery remains dependent on the approved server-side email worker.
- Quiz engine expanded to support Practice, Mock and Proctored Mock
- Registration security version 3 removes subject selection from identity
  registration and moves product choice to the catalogue
- Existing registration-selected subjects are preserved as complimentary
  entitlements so current learners retain access
- Dashboard access is derived from active entitlements instead of profile JSON
- Paid quiz starts require an active entitlement; demo attempts use active
  advanced questions and remain separate from paid practice attempt counts
- Cart changes use RPC-validated server prices; checkout remains disabled until
  a payment provider and signed-webhook fulfilment flow are approved
- Subject and question browser-table privileges are removed; learner and
  administrator access now uses the approved RPC boundaries
- Added a non-duplicating catalogue/admin compatibility repair that validates
  migration order, restores approved RPC ownership and grants, preserves
  subject/question hardening, and runtime-tests the public catalogue as anon
- Question difficulty labels map Easy, Moderate, and Hard to the existing
  Foundation, Intermediate, and Advanced database values
- Repaired administrator question saves so A/B/C/D form tags are resolved to
  the full option text required by quiz scoring, with a guarded repair for
  affected administrator-audited questions
- Security moved to RPC-first architecture
- Suspended or closed learners remain managed only through the audited
  Security & Alerts workflow; the existing activation RPC signature and its
  active/verification-pending boundary remain unchanged
- Repaired the quiz-start client script so it parses and relies on the existing
  quiz RPC flow without directly reading `quiz_attempts`
- Added repeatable frontend syntax and local-link verification
- Documented the current RPC inventory and missing version-controlled definitions
- Added a read-only SQL audit for deployed RPC signatures, security settings,
  grants, and definitions
- Captured and reviewed the eight deployed quiz and profile RPC definitions
- Added a signature-preserving migration to prevent final-only answer disclosure,
  reject late quiz submissions, and remove anonymous answer submission access
- Updated the quiz client to use database-configured question counts, time limits,
  and the authoritative attempt start time
- Added a profile-table privilege migration that removes anonymous access and
  browser-role write, truncate, reference, and trigger privileges
- Consolidated the profile security audit into one exportable result set
- Added trusted auth-trigger profile creation and moved registration values to
  Supabase sign-up metadata
- Enabled profile RLS with a single authenticated own-profile SELECT policy
- Hardened `save_user_profile` with `auth.uid()` ownership validation while
  preserving its deployed signature
- Deployed and verified the profile privilege, registration trigger, and RLS
  migrations
- Added stage-specific quiz-start timeouts and recovery so stalled RPC requests
  identify whether attempt creation or question loading failed
- Added static regression coverage for both timeout-protected quiz-start stages
- Changed successful quiz completion to return the signed-in learner directly
  to the dashboard without calling logout
- Froze System Architecture Version 1.1 following project-owner approval
- Added the approved one-active-session security requirement and identity
  portability principle
- Added a repository health baseline and streamlined mission execution gates
- Added a privacy-preserving, read-only audit for existing authentication
  session controls and potential duplicate objects
- Documented the database, RPC, rollback, and active-quiz recovery design for
  strict one-active-session enforcement
- Captured the live Auth session audit: no duplicate custom session objects were
  found, and one user had two potentially active sessions
- Recorded the Free-plan Auth configuration and 3,600-second JWT expiry
- Prepared central PostgREST enforcement of the newest Supabase Auth session,
  with rollback and catalogue verification and no existing RPC signature change
- Updated login to revoke other refresh-token sessions and added safe displaced-
  session handling to the dashboard and quiz pages
- Refined the approved concurrency rule so the first active page remains in
  control unless the user explicitly selects **Use this login** on a later page
- Froze System Architecture Version 1.2 with the approved first-active-page,
  explicit-transfer, duplicate-tab, global-logout, and lease-recovery rules
- Added staged, reversible active-client lease migrations with strict trusted
  JWT session, client-header, lease-expiry, RLS, and privilege validation
- Added shared login/dashboard/quiz session control for duplicate-tab blocking,
  cross-browser conflict confirmation, ten-second heartbeat checks, safe
  displacement, 90-second closed-browser recovery, and explicit global logout
- Added final active-client lease catalogue verification, expanded canonical
  frontend static checks, and added behavior checks for lease claim, conflict
  cancellation, explicit transfer, duplicate-tab control, and global logout
- Added a protected registration migration with a Before User Created Auth
  hook, trusted referral capture, complete-profile enforcement, dual email and
  mobile verification, and an active-profile Data API gate
- Disabled registration submission until the configured Turnstile widget is
  available, so the temporary security warning cannot be bypassed by local
  field validation
- Configured the production Cloudflare Turnstile public Site Key for the
  approved InsureGPTE hostnames and added a static check that rejects the
  deployment placeholder
- Improved registration usability with a separate India/default or manual
  international calling code, country-aware Indian PIN validation, an
  India-or-manual country selector, and accessible password visibility controls
- Added authentication-and-test-only screen protection that blocks copy, cut,
  paste, and protected-page printing, and adds a visible screenshot deterrence
  watermark without affecting dashboard or future learning pages
- Changed active-quiz Back and Logout actions to finalize submitted answers
  before returning to the dashboard or signing out, with an explicit
  **Continue Quiz** option and no navigation when finalization fails
- Disabled the right-click context menu only on the combined authentication,
  registration, and verification page while preserving it on the test,
  dashboard, and future learning pages
- Preserved the deployed `save_user_profile` signature while preventing null
  profile fields, unverified mobile changes, invalid subjects, and accidental
  reactivation of suspended or closed accounts
- Rebuilt the registration interface with accessible field guidance, mandatory
  validation, 12–64 character password checks, at least one subject, referral
  source capture, Cloudflare Turnstile readiness, email OTP, and mobile OTP
- Added read-only suspicious-registration, incomplete-profile, duplicate-mobile,
  stale-phone-change, Auth-session, and Auth-audit inspection SQL
- Added protected-registration catalogue/behavior verification, rollback SQL,
  frontend behavior tests, and a controlled production activation guide
- Temporarily changed protected-account activation to email OTP only while
  retaining required normalized unique mobile data, preserving any existing
  mobile-verification evidence, and deferring SMS OTP until a production
  provider plan is approved
- Added a reversible email-only activation migration, existing-user backfill,
  deployment verification SQL, and frontend regression coverage
- Restored the quiz completion confirmation panel so submitting the final
  answer no longer navigates away immediately, keeps the authenticated session
  active, and returns to subject selection only when the learner requests it
- Added regression coverage for final-result visibility, safe page-control
  handoff, and dashboard attempt counts across completed, in-progress, and
  abandoned attempts
- Repaired the safety-event helper's ten-column insert, preserved its existing
  signature and restrictions, and added transactional insert/deduplication
  verification so lazy PL/pgSQL statement errors cannot pass catalogue checks

### Planned

- Remaining RPC development
- Dashboard analytics
- Learning APIs
- Recommendation engine
- Admin portal
- Payment gateway
- AI tutor
- Production deployment
