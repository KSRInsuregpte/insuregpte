-- Learning is free for active registered users. Practice access remains
-- entitlement-gated. Flashcards are learning content, not paid practice.

CREATE OR REPLACE FUNCTION public.get_flashcards(p_topic_id integer)
RETURNS TABLE (
    flashcard_id bigint,
    flashcard_code text,
    question text,
    answer text,
    explanation text,
    display_order integer,
    difficulty_level text,
    is_exam_relevant boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_subject_id integer;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to review flashcards.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id
          AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT topic_record.subject_id INTO v_subject_id
    FROM public.subject_topics AS topic_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND subject_record.is_active = true
    WHERE topic_record.id = p_topic_id
      AND topic_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The selected topic is not available.';
    END IF;

    RETURN QUERY
    SELECT
        flashcard_record.id::bigint,
        flashcard_record.code,
        flashcard_record.question,
        flashcard_record.answer,
        flashcard_record.explanation,
        flashcard_record.display_order,
        flashcard_record.difficulty_level,
        flashcard_record.is_exam_relevant
    FROM public.flashcards AS flashcard_record
    WHERE flashcard_record.topic_id = p_topic_id
      AND flashcard_record.subject_id = v_subject_id
      AND flashcard_record.is_active = true
    ORDER BY flashcard_record.display_order, flashcard_record.id;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_flashcards(integer)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_flashcards(integer)
TO authenticated;

COMMENT ON FUNCTION public.get_flashcards(integer) IS
    'Returns active learning flashcards to active registered users; paid practice remains entitlement-gated.';

NOTIFY pgrst, 'reload schema';
