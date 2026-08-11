# Academic Hierarchy Test Deployment

Use this sequence for the `test/academic-hierarchy-freeze` preview. A Vercel
preview deploys frontend files only; it does not execute Supabase SQL.

## Before any database change

Do not run the migrations first. Complete this safe audit and send its result
to the developer for review:

1. Open the Supabase project dashboard.
2. Select **SQL Editor** in the left menu.
3. Select **New query**.
4. Open `TESTING/sql/academic-hierarchy-predeployment-audit.sql` from the test
   branch, copy the complete SQL, and paste it into the query editor.
5. Select **Run**. This audit is read-only and does not change any record.
6. Confirm one result grid appears with five rows.
7. Use the result grid's export/download option to save the rows as CSV.
8. Attach that CSV to the Codex task. Stop here until the developer confirms
   that the result is safe for migration.

If the first audit identifies legacy hierarchy records, the developer may ask
for `TESTING/sql/academic-hierarchy-legacy-dependency-audit.sql`. Run it by the
same copy, paste, **Run**, export, and attach process. It is also read-only.
Do not run either migration until both requested audits have been reviewed.

The 2026-08-11 dependency audit was reviewed and confirmed 20 legacy III
Optional Credit subjects, no linked examination-information records, no Life
Broker subject usage, and two legacy category values. The approved migration
preserves all subject IDs and activation states while mapping IC14 to
Licentiate/Compulsory, IC23–IC78 papers from the audited list to
Associate/Optional Credit, and IC82–IC99 papers from the audited list to
Fellowship/Optional Credit. `Common` and `Foundation` normalize to
`Common (Life & Non-Life)`.

## Required deployment order after audit approval

1. Confirm the connected test database is the intended Supabase project:
   `tvjsivuibvzybdbjtesq`.
2. In that project's Supabase SQL Editor, run
   `supabase/migrations/20260810120000_freeze_academic_hierarchy.sql`.
3. Run
   `supabase/migrations/20260811100000_repair_programme_section_assignments.sql`.
4. Run `TESTING/sql/academic-hierarchy-freeze-verification.sql`.
5. Treat any exception as a failed deployment. Do not continue to browser
   acceptance testing until the verification completes successfully. Both
   migrations use explicit transactions, so an exception rolls back that
   migration instead of retaining a partial hierarchy change.
6. Reload the Vercel preview with a hard refresh so
   `js/admin.js?v=20260811b` is loaded.

## Expected Admin values

The Qualification Level dropdown must contain exactly:

1. Licentiate Exam Preparation
2. Associate Exam Preparation
3. Fellowship Exam Preparation
4. Spl. Dip Exam Preparation
5. Surveyor Exam Preparation
6. NIA - Direct Broker Exam Preparation
7. NIA - Reinsurance Broker Exam Preparation
8. NIA - Composite Broker Exam Preparation

The Programme dropdown must contain exactly five III programmes and three NIA
programmes. `Life Broker Training` and `III Optional Credit Subjects` must not
appear as programmes. Direct Broker must appear as
`Direct Broker – General, Life and Health Training` and its stored description
must be `General, Life and Health Training`.

After a Programme is selected, the Programme Section dropdown must show only
sections belonging to that programme. Approved section labels are Compulsory,
Compulsory Optional, Optional Credit, General Insurance, Life Insurance,
Reinsurance, Broker, Surveyor, and Spl_Diploma, subject to their approved
programme relationships.

The Subject Category field must be a required dropdown containing exactly
General Insurance, Life Insurance, Common (Life & Non-Life), and Regulation
and Compliance. Custom values must be rejected.

## Acceptance test

1. Edit inactive subject IC45.
2. Confirm Associate Exam Preparation and III - Associate Exam Preparation are
   selected.
3. Confirm only the Associate programme's sections appear.
4. Select the intended section and save without changing activation status.
5. Confirm the success message and corresponding audit-history entry.
6. Confirm the Subject Category dropdown contains exactly the four approved
   values and that a value outside that list cannot be entered or saved.

## Rollback

Use the corresponding rollback scripts in reverse order. The section-assignment
repair is intentionally retained because restoring invalid cross-programme
references would recreate the save failure.
