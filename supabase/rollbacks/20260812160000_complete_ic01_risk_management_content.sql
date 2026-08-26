-- Remove only content introduced for IC01 Risk Management Topics 2-7.
-- Topic records, Topic 1 pilot content, and all learner records are preserved.

BEGIN;

DELETE FROM public.flashcards
WHERE pg_catalog.upper(code) BETWEEN
      'FC-IC01-C01-T02-001' AND 'FC-IC01-C01-T07-003';

DELETE FROM public.learning_resources
WHERE pg_catalog.upper(code) BETWEEN
      'LR-IC01-C01-T02-001' AND 'LR-IC01-C01-T07-002';

COMMIT;
