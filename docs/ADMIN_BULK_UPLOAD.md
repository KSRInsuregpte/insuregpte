# Administrator Bulk CSV Upload

## Purpose

The hidden InsureGPTE administrator dashboard supports reviewed CSV imports
for the existing:

- user activation status;
- academic hierarchy;
- subject master;
- learning hierarchy and content;
- question bank;
- official examination-information register; and
- non-payment entitlements.

The feature supplements the existing one-record-at-a-time Admin forms. It does
not replace or change their working signatures.

## Architecture and security

The browser reads, checks, and previews a CSV for usability. PostgreSQL remains
the authoritative security boundary.

`admin_bulk_import(text,jsonb)`:

1. requires an authenticated, active administrator;
2. permits only the fixed upload types listed in this guide;
3. limits one file to 250 data rows;
4. applies the entire file in one transaction;
5. stops and saves nothing from the file when any row fails;
6. delegates existing subjects, questions, users, and examination information
   to their existing audited Admin save functions;
7. delegates academic and learning records to
   `admin_save_academic_content(text,jsonb)`; and
8. delegates non-payment access to the stricter
   `admin_save_entitlement(jsonb)`.

No data table is added. The frontend remains RPC-only.

The importer cannot:

- create a Supabase Auth identity;
- change a password, email, profile, or administrator role;
- create or alter a purchase or subscription entitlement;
- confirm an unverified email; or
- bypass the existing hierarchy, active-user, and audit checks.

## Required upload order

Parent records must exist before their children. Use this sequence:

1. Qualification Levels
2. Examination Authorities
3. Training Programmes
4. Programme Sections
5. Subject Master
6. Learning Modules
7. Learning Chapters
8. Learning Topics
9. Learning Resource Types
10. Learning Resources and Flashcards
11. Question Bank
12. Examination Information
13. Existing User Status
14. Non-payment Entitlements

The same sequence appears in the downloadable Excel guide.

## Downloadable formats

The Admin **Bulk Upload** tab provides a matching CSV download for the selected
upload type and one complete reference workbook:

`admin-upload-templates/admin-bulk-upload-formats.xlsx`

The workbook is a guide and is not uploaded directly. Complete the relevant
sheet, then save or export that sheet as CSV without changing its first-row
header.

### Academic hierarchy

- `qualification-levels.csv`
- `exam-authorities.csv`
- `training-programmes.csv`
- `programme-sections.csv`
- `subjects.csv`

Stable codes identify hierarchy records. A repeated stable code updates its
existing record; a new code creates a record. Programme sections use the
combination of `programme_code` and section `code`.

The existing subject contract still uses optional hierarchy IDs. Leave `id`
blank to create a new subject and provide an existing numeric `id` to update a
subject. A new subject must use `is_active=false`.

### Learning structure and content

- `modules.csv`
- `chapters.csv`
- `topics.csv`
- `learning-resource-types.csv`
- `learning-resources.csv`
- `flashcards.csv`

These formats use `subject_code`, `module_code`, `chapter_code`, and
`topic_code` to confirm the full parent path.

Learning resources must include at least one of:

- `content`;
- an HTTPS `external_url`; or
- `attachment_path`.

`is_premium=true` marks content that the learner may receive only through an
active subject entitlement. Uploading premium content does not grant access.

Topic and flashcard difficulty uses the stored levels:

- `foundation`
- `intermediate`
- `advanced`

### Question bank

`questions.csv` continues to support the current single-answer MCQ contract.

- `correct_option`: `A`, `B`, `C`, or `D`
- Admin display difficulty: `Easy`, `Moderate`, or `Hard`
- `is_active`: `true` or `false`

The existing question save function converts A-D to the full option text
required by quiz scoring and maps difficulty to Foundation, Intermediate, or
Advanced.

### Examination information

`exam-information.csv` covers official metadata and links for:

- examination schedules;
- centre lists;
- language lists;
- handbooks;
- syllabi;
- credit-point documents;
- subject amendments;
- withdrawal notices; and
- other official notices.

It reuses `regulatory_academic_publications`; no timetable, centre, amendment,
or notice table is created.

Use an unchanging `source_document_id` for each official document. Authority,
programme, section, and subject are referenced by stable codes. Session code
and valid-until date are mandatory for schedules, centre lists, and language
lists. Official and optional discovery URLs must use HTTPS.

### Existing users

`users.csv` contains:

`email,status`

- The email must already exist in Supabase Auth and `profiles`.
- Status supports only `active` or `verification_pending`.
- Activation requires a verified email.
- Administrator accounts cannot be made verification-pending.

### Non-payment entitlements

`entitlements.csv` is only for a documented Admin grant to an existing active
user. It supports:

- `complimentary`
- `promotional`
- `admin_grant`

It cannot create or change `purchase` or `subscription` access. Those remain
reserved for the future verified payment workflow.

Leave `id` blank to create a grant. Supply the existing entitlement UUID to
update a grant. An existing entitlement cannot be reassigned to another user
or subject. Every row requires a traceable `source_reference`.

## Trial deployment and verification

1. Deploy `20260730150000_add_admin_bulk_import.sql`.
2. Run `TESTING/sql/admin-bulk-import-verification.sql`.
3. Deploy `20260731120000_expand_admin_bulk_import.sql`.
4. Run `TESTING/sql/admin-expanded-bulk-import-verification.sql`.
5. Deploy `20260731180000_expand_admin_audit_entity_types.sql`.
6. Run `TESTING/sql/admin-audit-entity-types-verification.sql`.
7. Deploy the matching frontend branch to a Vercel Preview.
8. Download formats from the Preview Admin page.
9. Test one or two inactive/non-production rows in dependency order.
10. Confirm each change in the existing Admin lists and Audit History.
11. Confirm a failed row causes the complete file to save nothing.
12. Approve production deployment only after the trial results pass.

## Rollback

Run the rollbacks in reverse order:

1. `supabase/rollbacks/20260731180000_expand_admin_audit_entity_types.sql`
2. `supabase/rollbacks/20260731120000_expand_admin_bulk_import.sql`
3. `supabase/rollbacks/20260730150000_add_admin_bulk_import.sql`

Rollback removes the bulk routes but does not automatically delete legitimate
audited records already imported. If an `official_notice` record exists, its
compatible document-type constraint is retained so rollback cannot invalidate
stored data. The audit-constraint rollback stops when expanded audit history
exists; never delete audit records merely to force rollback.
