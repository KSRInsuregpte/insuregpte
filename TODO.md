# InsureGPTE TODO

## Phase 1 (Completed)
- [x] Authentication
- [x] Registration
- [x] Login
- [x] Email Verification
- [x] Dashboard
- [x] Database Hierarchy
- [x] Learning Resources
- [x] Flashcards
- [x] Quiz Engine
- [x] Progress Tracking
- [x] Shopping Cart
- [x] User Entitlements

---

## Phase 2 (Current)

- [x] Freeze and approve Version 1.0 system architecture
- [x] Review all existing RPCs
- [x] Create repository health baseline
- [x] Confirm Supabase plan, session settings, and 3,600-second JWT expiry
- [x] Run and review `audit-auth-session-controls.sql`
- [x] Implement staged first-active-page lease enforcement in the repository
- [x] Implement protected registration, referral capture, CAPTCHA integration,
  email OTP, mobile OTP, and server-side completeness enforcement in the
  repository
- [ ] Audit and quarantine the suspicious unverified registration
- [ ] Configure the Before User Created hook in Supabase Auth
- [ ] Configure Cloudflare Turnstile in Cloudflare, the frontend, and Supabase
- [ ] Configure the email confirmation template for six-digit OTP entry
- [x] Validate the standard Supabase/Twilio mobile OTP integration in a
  controlled trial
- [x] Temporarily activate protected accounts after email OTP only
- [ ] Configure the 12-character minimum Auth password policy
- [ ] Deploy and runtime-verify protected registration end to end
- [ ] Deploy and runtime-verify first-active-page enforcement
- [ ] Deploy and verify hardened `submit_quiz_answer`
- [x] Keep the final quiz result visible and preserve login until the learner
  explicitly returns to subject selection or logs out
- [x] Harden `start_quiz_attempt` entitlement, active-question, and concurrency rules in the repository
- [x] Remove subject selection from registration and add the catalogue-first frontend
- [x] Add server-priced cart RPCs and entitlement-based dashboard access
- [x] Add a 10-question advanced-difficulty demo mode separate from practice counts
- [x] Create and validate the trial regulatory source register
- [x] Add a privacy-safe live hierarchy and examination-object audit
- [x] Map reviewed regulatory metadata to the existing academic hierarchy in a guarded trial migration
- [x] Add session-aware examination information through an audited RPC
- [x] Deploy and verify the regulatory metadata/session-information migration in trial
- [x] Deploy and runtime-verify catalogue, cart, entitlement, and demo migrations
- [x] Run the catalogue/admin compatibility repair after the catalogue, demo,
  regulatory metadata, and admin migrations are deployed in timestamp order
- [ ] Select a production payment provider and approve signed-webhook fulfilment design
- [ ] Make quiz finalization idempotent and time-limit safe
- [ ] Complete remaining RPCs
- [ ] Dashboard APIs
- [ ] Learning APIs
- [ ] Analytics APIs
- [ ] Recommendation APIs
- [x] Add a privacy-safe live admin-role, management-object, and commerce audit
- [x] Add server-enforced, audited admin APIs and the hidden admin dashboard
- [x] Deploy and runtime-verify the admin migration and admin dashboard
- [x] Repair administrator question saves to preserve the quiz engine's
  full-answer-text scoring contract
- [x] Deploy and verify the administrator question-answer compatibility repair
- [x] Add guarded, atomic administrator CSV formats and bulk upload for
  existing-user status, the academic hierarchy, subjects, learning content,
  question-bank content, official exam information, and non-payment grants
- [ ] Deploy and runtime-verify administrator bulk upload in trial before
  production use
- [ ] Deploy and verify the administrator audit entity-type compatibility
  repair before retrying the controlled bulk import

---

## Phase 3

- [ ] Replace direct frontend table reads with approved RPCs
- [ ] Centralize Supabase client and authentication handling
- [ ] Frontend refactoring
- [ ] Move inline JavaScript to separate files
- [ ] Move inline CSS to separate files
- [ ] Componentize UI
- [ ] Mobile optimization

---

## Phase 4

- [ ] Populate educational content
- [ ] Complete testing
- [ ] Complete cross-user, cross-browser, and single-session testing
- [ ] Performance optimization
- [ ] Production deployment

---

## Phase 5 (Post-launch)

- [ ] Add optional postal/PIN-based address lookup after the initial product launch
- [ ] Purchase and configure the production SMS plan, then restore mobile OTP
  activation through the approved rollback/change process
