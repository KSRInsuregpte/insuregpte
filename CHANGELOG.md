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
- PROJECT_CONTEXT.md
- CODING_RULES.md

### Changed

- Database normalized into hierarchical academic structure
- Quiz engine expanded to support Practice, Mock and Proctored Mock
- Security moved to RPC-first architecture
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

### Planned

- Remaining RPC development
- Dashboard analytics
- Learning APIs
- Recommendation engine
- Admin portal
- Payment gateway
- AI tutor
- Production deployment
