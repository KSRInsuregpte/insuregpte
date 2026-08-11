# Learning Module controlled release

## Purpose

The Version 1.0 Learning Module presents the existing subject → module →
chapter → topic hierarchy and its approved resources and flashcards. It records
owned topic progress and activity without exposing the underlying tables to the
browser.

## Database impact

The release creates the 12 approved Learning and hierarchy RPCs. It does not
create a table and does not update or delete existing academic, resource,
flashcard, progress, activity, or entitlement rows.

The audited legacy
`upsert_user_topic_progress(uuid,integer,text,numeric,integer)` signature is
preserved, but now requires an active authenticated caller and rejects a user ID
other than `auth.uid()`. Anonymous execution is removed.

Direct browser privileges are removed from the hierarchy and Learning tables.
Existing audited administrator functions remain able to maintain content as
`SECURITY DEFINER` functions.

## Access rules

- all Learning RPCs require an active signed-in profile;
- active non-premium resources are available to an active learner;
- premium resource payloads are redacted without a current subject entitlement;
- flashcards require a current subject entitlement;
- progress and activity are always written for `auth.uid()`;
- progress percentage and total learning time cannot decrease;
- completed topics remain completed;
- inactive hierarchy and content records are never returned.

## Activity reference contract

| Activity type | `reference_id` |
| --- | --- |
| `resource_viewed`, `note_viewed` | `learning_resources.id` in the same topic |
| `flashcard_reviewed` | `flashcards.id` in the same topic |
| `topic_started`, `topic_completed`, `revision_completed` | `NULL` |

The RPC validates the referenced row, hierarchy, activity type, access, and
duration before inserting the append-only activity record.

## Trial deployment order

1. Run `TESTING/sql/learning-module-object-audit.sql` and review the export.
2. Run `supabase/migrations/20260811150000_build_learning_module.sql` in the
   trial Supabase SQL Editor.
3. Run `TESTING/sql/learning-module-verification.sql`.
4. Deploy the `test/learning-module` frontend preview.
5. Test with an active entitled learner and an active learner without the
   entitlement.
6. Merge only after database and browser acceptance results are reviewed.

## Browser acceptance

1. Sign in as an active entitled learner.
2. Open **Learning** from the dashboard.
3. Confirm module, chapter, and topic ordering.
4. Open a resource and confirm its content is readable.
5. Review a flashcard and reveal its answer.
6. Mark a topic complete; confirm it shows 100% after refresh.
7. Sign in as a second active learner and confirm the first learner's progress
   is not visible.
8. Without entitlement, confirm free resources remain available, premium
   payloads remain locked, and flashcards are rejected.
9. Confirm an inactive learner is displaced by the existing session controls.

## Rollback

Run `supabase/rollbacks/20260811150000_build_learning_module.sql`. It drops only
the new RPCs, restores the audited legacy progress function and its former
grants, and retains all content and learner history.
