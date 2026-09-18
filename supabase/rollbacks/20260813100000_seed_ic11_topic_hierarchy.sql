-- Roll back the IC11 topic hierarchy only before learner activity or content exists.

BEGIN;

DO $guard$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.subject_topics AS topic_record
        WHERE pg_catalog.upper(topic_record.code) LIKE 'IC11-C__-T__'
          AND (
              EXISTS (
                  SELECT 1 FROM public.learning_resources AS resource_record
                  WHERE resource_record.topic_id = topic_record.id
              )
              OR EXISTS (
                  SELECT 1 FROM public.flashcards AS flashcard_record
                  WHERE flashcard_record.topic_id = topic_record.id
              )
              OR EXISTS (
                  SELECT 1 FROM public.user_topic_progress AS progress_record
                  WHERE progress_record.topic_id = topic_record.id
              )
              OR EXISTS (
                  SELECT 1 FROM public.user_learning_activity AS activity_record
                  WHERE activity_record.topic_id = topic_record.id
              )
          )
    ) THEN
        RAISE EXCEPTION
            'IC11 topics have dependent content or learner history. Roll back dependent content first and preserve learner records.';
    END IF;
END;
$guard$;

DELETE FROM public.subject_topics AS topic_record
WHERE pg_catalog.upper(topic_record.code) LIKE 'IC11-C__-T__'
  AND topic_record.subject_id = (
      SELECT subject_record.id
      FROM public.subjects AS subject_record
      WHERE pg_catalog.upper(subject_record.code) = 'IC11'
  );

COMMIT;
