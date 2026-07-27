# Regulatory Source Register

## Purpose

This trial register controls which external academic and regulatory documents
may be used to prepare InsureGPTE catalogue metadata, original learning
content, and original practice questions.

It prevents an old book, a third-party document, a duplicate file, or an
expired examination notice from being treated as the current official source.

The machine-readable register is:

```text
docs/regulatory-source-register.json
```

## Scope of this step

This step:

- records the reviewed III handbook, syllabus, credit-point notices, schedules,
  centre lists, withdrawal notice, and downloaded subject amendments;
- identifies IC01, IC02, IC11, and IC14 as the first trial subjects;
- blocks withdrawn IC23 and IC82 from new commercial use;
- marks all four pilot subjects as requiring learning-content review before
  sale;
- quarantines third-party, misplaced, personally identifying, or
  copyright-sensitive source material;
- records known exact duplicate groups without deleting user files.

This step does not:

- create or alter a database table;
- create or replace an RPC;
- change the catalogue, cart, entitlement, registration, or quiz frontend;
- copy the source PDFs into the repository;
- authorize publication of full III or third-party study books;
- approve a subject for sale.

## Controlling source order

When sources disagree, use this order:

1. current official examination handbook;
2. current official syllabus or credit-point notice;
3. subject-specific official amendment or withdrawal notice;
4. session-specific official timetable and centre list.

The printed date inside an official document controls over a downloaded
filename. Filenames are storage labels and are not reliable effective dates.

## Amendment workflow

When IRDAI issues a regulation that results in a III subject amendment:

1. add the official amendment to the register;
2. record the printed publication or update date;
3. connect it to the affected subject and base edition;
4. identify affected lessons and questions;
5. revise and independently review InsureGPTE's original content;
6. publish a new content version with an "Updated to amendment dated ..."
   notice;
7. retain the prior version and review evidence for audit.

An amendment must never silently replace reviewed learning content.

## Time-sensitive information

Timetables, bilingual-paper lists, and examination-centre lists are snapshots
for a named examination session. They must include a `valid_until` date and
must not be displayed as permanent reference data after expiry.

The September 2026 entries expire after 30 September 2026. A later III
publication must be reviewed and registered before replacing them.

## Content and copyright rule

Public availability of a study PDF does not grant InsureGPTE permission to
republish it. Full books remain reference material unless written publication
rights are confirmed.

InsureGPTE should publish original:

- lesson explanations;
- revision notes;
- worked examples;
- flashcards;
- question stems, options, answers, and explanations.

Every learning item and question should record the source version used during
its review without copying excessive source text.

## Database boundary

The existing trial work already reuses:

- `qualification_levels`;
- `exam_authorities`;
- `training_programmes`;
- `programme_sections`;
- `subjects`;
- `carts`;
- `cart_items`;
- `user_entitlements`;
- `learning_resources`.

The source register does not duplicate those objects. Its next approved use is
to validate catalogue metadata before that metadata is applied to the existing
academic hierarchy through version-controlled SQL and existing or audited
RPCs.

### Live database audit prerequisite

The repository design stores only one `qualification_level_id`, one
`training_programme_id`, and one `programme_section_id` on each subject. Shared
papers such as IC01 and IC14 must therefore be reconciled against the live
hierarchy before approved source metadata is mapped.

Run
`TESTING/sql/regulatory-academic-hierarchy-audit.sql` in the trial Supabase SQL
editor and export its single result grid. The audit reads only database object
metadata and non-personal academic catalogue rows. It does not inspect
profiles, authentication users, email addresses, or mobile numbers.

The audit must confirm:

- the live codes and identifiers for qualification levels, authorities,
  programmes, sections, and pilot subjects;
- whether a pilot code has zero, one, or multiple subject rows;
- whether an examination session, timetable, centre, notice, amendment, or
  regulatory object already exists;
- whether any proposed examination-information RPC name is already in use.

No session table, mapping table, or RPC may be added until the exported audit
has been reviewed. This is the duplication-control gate for the next trial
migration.

The reviewed live audit confirmed:

- the required academic hierarchy objects exist;
- IC01, IC11, and IC14 each have one live subject row;
- IC02 is not yet present and may be introduced only as inactive metadata;
- withdrawn IC23 and IC82 are absent;
- no examination-session, centre, timetable, amendment, or notice table
  exists;
- `get_exam_information` is not already defined.

The trial implementation therefore adds only
`regulatory_academic_publications`, maps its rows to the existing hierarchy, and
exposes current session information through `get_exam_information`. IC02
remains unavailable for demos, purchases, and learning until its content is
reviewed and separately approved.

## Next implementation gate

Before a trial subject changes from `metadata_ready` to available:

1. confirm its current syllabus and credit points;
2. establish the base edition and all applicable amendments;
3. complete copyright and originality review;
4. review learning content;
5. verify at least ten advanced demo questions;
6. verify the paid practice question inventory;
7. approve price, validity, and entitlement rules;
8. deploy and test only in the trial environment.
