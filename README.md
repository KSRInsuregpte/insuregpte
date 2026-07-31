# InsureGPTE

Insurance learning, revision, demonstration, and practice platform.

Current learner journey:

1. Register and verify the email address.
2. Browse the categorized subject catalogue.
3. Review a learning path or take a free advanced-question demo.
4. Add paid subjects to the server-priced cart.
5. Use entitled subjects from the practice dashboard.

Payment collection is intentionally disabled until a production provider and
signed server-side payment confirmation process are approved.

Regulatory, syllabus, timetable, centre, withdrawal, and amendment sources are
governed by the trial register in
`docs/regulatory-source-register.json`. The register does not authorize
republication of full source books or activate a subject for sale.

The trial database mapping reuses the existing academic hierarchy and exposes
only current verified session notices through the authenticated
`get_exam_information` RPC. IC02 remains inactive until learning and question
content pass review.

Administrators use `admin-dashboard.html`. The page is hidden from ordinary
learners and every management operation is independently authorized by the
database. The current administration release manages subjects, reviewed MCQ
questions and explanations, user activation status, and verified examination
information. It does not change Auth passwords or administrator roles.
Administrator question forms use A/B/C/D selectors for usability, while the
database stores the corresponding full option text required by the existing
quiz-scoring contract.

The administrator **Bulk Upload** tab provides fixed CSV downloads for existing
user status, academic hierarchy, subjects, learning content, questions,
official examination information, and non-payment entitlements. Every file is
previewed before import and then applied atomically through audited Admin save
RPCs. See `docs/ADMIN_BULK_UPLOAD.md` for the required dependency order,
formats, safeguards, deployment sequence, and rollback.

The trial database migrations must be deployed in timestamp order. In
particular, deploy the catalogue and demo migrations before the admin
hardening migration. If admin hardening was applied first, deploy the missing
catalogue/demo migrations and then run
`20260728100000_restore_catalogue_admin_compatibility.sql`; do not restore
direct browser access to `subjects` or `questions`.
