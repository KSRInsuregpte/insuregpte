-- Roll back the Learning Module RPC release.
-- Existing learning content, learner progress, activity, and entitlements are
-- retained. The audited legacy progress function and previous browser grants
-- are restored exactly to their pre-release compatibility state.

BEGIN;

DROP FUNCTION IF EXISTS public.get_subject_hierarchy(bigint);
DROP FUNCTION IF EXISTS public.get_modules_by_subject(bigint);
DROP FUNCTION IF EXISTS public.get_chapters_by_module(integer);
DROP FUNCTION IF EXISTS public.get_topics_by_chapter(integer);
DROP FUNCTION IF EXISTS public.get_topic_details(integer);
DROP FUNCTION IF EXISTS public.get_learning_resources(integer);
DROP FUNCTION IF EXISTS public.get_flashcards(integer);
DROP FUNCTION IF EXISTS public.record_learning_activity(integer, text, bigint, integer, numeric);
DROP FUNCTION IF EXISTS public.get_resume_learning(bigint);
DROP FUNCTION IF EXISTS public.get_recent_activity(integer);
DROP FUNCTION IF EXISTS public.get_topic_completion(integer);
DROP FUNCTION IF EXISTS public.get_learning_statistics(bigint);

CREATE OR REPLACE FUNCTION public.upsert_user_topic_progress(
    p_user_id uuid,
    p_topic_id integer,
    p_status text,
    p_completion_percentage numeric,
    p_time_spent_minutes integer DEFAULT 0
)
RETURNS public.user_topic_progress
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_progress public.user_topic_progress;
BEGIN
    IF p_status NOT IN ('not_started', 'in_progress', 'completed') THEN
        RAISE EXCEPTION 'Invalid progress status: %', p_status;
    END IF;

    IF p_completion_percentage < 0
       OR p_completion_percentage > 100 THEN
        RAISE EXCEPTION
            'Completion percentage must be between 0 and 100';
    END IF;

    INSERT INTO public.user_topic_progress (
        user_id,
        topic_id,
        status,
        completion_percentage,
        total_time_spent_minutes,
        last_accessed_at,
        completed_at
    )
    VALUES (
        p_user_id,
        p_topic_id,
        p_status,
        p_completion_percentage,
        GREATEST(COALESCE(p_time_spent_minutes, 0), 0),
        NOW(),
        CASE
            WHEN p_status = 'completed' THEN NOW()
            ELSE NULL
        END
    )
    ON CONFLICT (user_id, topic_id)
    DO UPDATE SET
        status = EXCLUDED.status,
        completion_percentage = EXCLUDED.completion_percentage,
        total_time_spent_minutes =
            public.user_topic_progress.total_time_spent_minutes
            + EXCLUDED.total_time_spent_minutes,
        last_accessed_at = NOW(),
        completed_at = CASE
            WHEN EXCLUDED.status = 'completed'
                THEN COALESCE(
                    public.user_topic_progress.completed_at,
                    NOW()
                )
            ELSE NULL
        END
    RETURNING *
    INTO v_progress;

    RETURN v_progress;
END;
$function$;

REVOKE ALL ON FUNCTION public.upsert_user_topic_progress(uuid, integer, text, numeric, integer)
FROM PUBLIC, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_user_topic_progress(uuid, integer, text, numeric, integer)
TO anon, authenticated;

GRANT ALL ON TABLE public.subject_modules TO anon, authenticated;
GRANT ALL ON TABLE public.subject_chapters TO anon, authenticated;
GRANT ALL ON TABLE public.subject_topics TO anon, authenticated;
GRANT ALL ON TABLE public.learning_resource_types TO anon, authenticated;
GRANT ALL ON TABLE public.learning_resources TO anon, authenticated;
GRANT ALL ON TABLE public.flashcards TO anon, authenticated;
GRANT ALL ON TABLE public.user_topic_progress TO anon, authenticated;
GRANT ALL ON TABLE public.user_learning_activity TO anon, authenticated;

COMMIT;
