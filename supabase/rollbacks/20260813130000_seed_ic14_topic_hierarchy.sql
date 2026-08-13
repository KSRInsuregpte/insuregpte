BEGIN;
DO $guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.subject_topics topic_record
    WHERE pg_catalog.upper(topic_record.code) LIKE 'IC14-C__-T__'
      AND (EXISTS (SELECT 1 FROM public.learning_resources r WHERE r.topic_id=topic_record.id)
        OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.topic_id=topic_record.id)
        OR EXISTS (SELECT 1 FROM public.user_topic_progress p WHERE p.topic_id=topic_record.id)
        OR EXISTS (SELECT 1 FROM public.user_learning_activity a WHERE a.topic_id=topic_record.id))
  ) THEN RAISE EXCEPTION 'IC14 topics have dependent content or learner history.'; END IF;
END;
$guard$;
DELETE FROM public.subject_topics topic_record
WHERE pg_catalog.upper(topic_record.code) LIKE 'IC14-C__-T__'
  AND topic_record.subject_id=(SELECT id FROM public.subjects WHERE pg_catalog.upper(code)='IC14');
COMMIT;
