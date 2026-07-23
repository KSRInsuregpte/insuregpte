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
- [ ] Harden `start_quiz_attempt` entitlement, active-question, and concurrency rules
- [ ] Make quiz finalization idempotent and time-limit safe
- [ ] Complete remaining RPCs
- [ ] Dashboard APIs
- [ ] Learning APIs
- [ ] Analytics APIs
- [ ] Recommendation APIs
- [ ] Admin APIs

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
