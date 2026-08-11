-- Build the authenticated Learning Module over the existing Version 1.0
-- hierarchy, resource, flashcard, progress, activity, and entitlement tables.
-- No learner or academic row is changed by this migration.
--
-- Prerequisite audit:
--   TESTING/sql/learning-module-object-audit.sql
--
-- Rollback:
--   supabase/rollbacks/20260811150000_build_learning_module.sql

BEGIN;

DO $guard$
DECLARE
    v_relation text;
    v_function text;
BEGIN
    FOREACH v_relation IN ARRAY ARRAY[
        'public.profiles',
        'public.subjects',
        'public.subject_modules',
        'public.subject_chapters',
        'public.subject_topics',
        'public.learning_resource_types',
        'public.learning_resources',
        'public.flashcards',
        'public.user_entitlements',
        'public.user_topic_progress',
        'public.user_learning_activity'
    ]
    LOOP
        IF pg_catalog.to_regclass(v_relation) IS NULL THEN
            RAISE EXCEPTION 'Required Learning relation % is missing.', v_relation;
        END IF;
    END LOOP;

    FOREACH v_function IN ARRAY ARRAY[
        'public.get_subject_hierarchy(bigint)',
        'public.get_modules_by_subject(bigint)',
        'public.get_chapters_by_module(integer)',
        'public.get_topics_by_chapter(integer)',
        'public.get_learning_resources(integer)',
        'public.get_flashcards(integer)',
        'public.get_topic_details(integer)',
        'public.record_learning_activity(integer,text,bigint,integer,numeric)',
        'public.get_resume_learning(bigint)',
        'public.get_recent_activity(integer)',
        'public.get_topic_completion(integer)',
        'public.get_learning_statistics(bigint)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_function) IS NOT NULL THEN
            RAISE EXCEPTION
                'Learning function % already exists; audit before deployment.',
                v_function;
        END IF;
    END LOOP;

    IF pg_catalog.to_regprocedure(
        'public.upsert_user_topic_progress(uuid,integer,text,numeric,integer)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'The audited legacy progress function is missing.';
    END IF;
END;
$guard$;

-- Browser roles use the controlled RPCs below. Administrator SECURITY DEFINER
-- functions retain owner-level access for governed content maintenance.
REVOKE ALL ON TABLE public.subject_modules FROM anon, authenticated;
REVOKE ALL ON TABLE public.subject_chapters FROM anon, authenticated;
REVOKE ALL ON TABLE public.subject_topics FROM anon, authenticated;
REVOKE ALL ON TABLE public.learning_resource_types FROM anon, authenticated;
REVOKE ALL ON TABLE public.learning_resources FROM anon, authenticated;
REVOKE ALL ON TABLE public.flashcards FROM anon, authenticated;
REVOKE ALL ON TABLE public.user_topic_progress FROM anon, authenticated;
REVOKE ALL ON TABLE public.user_learning_activity FROM anon, authenticated;

CREATE FUNCTION public.get_subject_hierarchy(p_subject_id bigint)
RETURNS TABLE (
    subject_id bigint,
    subject_code text,
    subject_title text,
    module_id integer,
    module_code text,
    module_title text,
    module_display_order integer,
    chapter_id integer,
    chapter_code text,
    chapter_title text,
    chapter_display_order integer,
    topic_id integer,
    topic_code text,
    topic_title text,
    topic_description text,
    learning_objective text,
    practical_relevance text,
    estimated_study_minutes integer,
    difficulty_level text,
    topic_display_order integer,
    resource_count bigint,
    flashcard_count bigint,
    progress_status text,
    completion_percentage numeric,
    last_accessed_at timestamptz,
    is_entitled boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to open the learning path.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id
          AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.subjects AS subject_record
        WHERE subject_record.id = p_subject_id
          AND subject_record.is_active = true
    ) THEN
        RAISE EXCEPTION 'The selected subject is not available.';
    END IF;

    RETURN QUERY
    SELECT
        subject_record.id::bigint,
        subject_record.code,
        subject_record.title,
        module_record.id,
        module_record.code,
        module_record.title,
        module_record.display_order,
        chapter_record.id,
        chapter_record.code,
        chapter_record.title,
        chapter_record.display_order,
        topic_record.id,
        topic_record.code,
        topic_record.title,
        topic_record.description,
        topic_record.learning_objective,
        topic_record.practical_relevance,
        topic_record.estimated_study_minutes,
        topic_record.difficulty_level,
        topic_record.display_order,
        (
            SELECT pg_catalog.count(*)
            FROM public.learning_resources AS resource_record
            WHERE resource_record.topic_id = topic_record.id
              AND resource_record.is_active = true
        ),
        (
            SELECT pg_catalog.count(*)
            FROM public.flashcards AS flashcard_record
            WHERE flashcard_record.topic_id = topic_record.id
              AND flashcard_record.is_active = true
        ),
        COALESCE(progress_record.status, 'not_started'),
        COALESCE(progress_record.completion_percentage, 0),
        progress_record.last_accessed_at,
        EXISTS (
            SELECT 1
            FROM public.user_entitlements AS entitlement_record
            WHERE entitlement_record.user_id = v_user_id
              AND entitlement_record.subject_id = subject_record.id
              AND entitlement_record.status = 'active'
              AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
              AND (
                  entitlement_record.valid_until IS NULL
                  OR entitlement_record.valid_until > pg_catalog.clock_timestamp()
              )
        )
    FROM public.subjects AS subject_record
    JOIN public.subject_modules AS module_record
      ON module_record.subject_id = subject_record.id
     AND module_record.is_active = true
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.subject_id = subject_record.id
     AND chapter_record.module_id = module_record.id
     AND chapter_record.is_active = true
    JOIN public.subject_topics AS topic_record
      ON topic_record.subject_id = subject_record.id
     AND topic_record.module_id = module_record.id
     AND topic_record.chapter_id = chapter_record.id
     AND topic_record.is_active = true
    LEFT JOIN public.user_topic_progress AS progress_record
      ON progress_record.user_id = v_user_id
     AND progress_record.topic_id = topic_record.id
    WHERE subject_record.id = p_subject_id
      AND subject_record.is_active = true
    ORDER BY
        module_record.display_order,
        module_record.id,
        chapter_record.display_order,
        chapter_record.id,
        topic_record.display_order,
        topic_record.id;
END;
$function$;

CREATE FUNCTION public.get_modules_by_subject(p_subject_id bigint)
RETURNS TABLE (
    module_id integer,
    module_code text,
    module_title text,
    module_description text,
    display_order integer,
    chapter_count bigint,
    topic_count bigint,
    completed_topic_count bigint,
    completion_percentage numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to view learning modules.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    RETURN QUERY
    SELECT
        module_record.id,
        module_record.code,
        module_record.title,
        module_record.description,
        module_record.display_order,
        (SELECT pg_catalog.count(*) FROM public.subject_chapters AS chapter_record
         WHERE chapter_record.module_id = module_record.id AND chapter_record.is_active = true),
        (SELECT pg_catalog.count(*) FROM public.subject_topics AS topic_record
         WHERE topic_record.module_id = module_record.id AND topic_record.is_active = true),
        (SELECT pg_catalog.count(*) FROM public.subject_topics AS topic_record
         JOIN public.user_topic_progress AS progress_record
           ON progress_record.topic_id = topic_record.id
          AND progress_record.user_id = v_user_id
          AND progress_record.status = 'completed'
         WHERE topic_record.module_id = module_record.id AND topic_record.is_active = true),
        COALESCE((
            SELECT pg_catalog.round(pg_catalog.avg(
                COALESCE(progress_record.completion_percentage, 0)
            ), 2)
            FROM public.subject_topics AS topic_record
            LEFT JOIN public.user_topic_progress AS progress_record
              ON progress_record.topic_id = topic_record.id
             AND progress_record.user_id = v_user_id
            WHERE topic_record.module_id = module_record.id
              AND topic_record.is_active = true
        ), 0)
    FROM public.subject_modules AS module_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = module_record.subject_id
     AND subject_record.is_active = true
    WHERE module_record.subject_id = p_subject_id
      AND module_record.is_active = true
    ORDER BY module_record.display_order, module_record.id;
END;
$function$;

CREATE FUNCTION public.get_chapters_by_module(p_module_id integer)
RETURNS TABLE (
    chapter_id integer,
    chapter_number integer,
    chapter_code text,
    chapter_title text,
    chapter_description text,
    display_order integer,
    topic_count bigint,
    completed_topic_count bigint,
    completion_percentage numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to view learning chapters.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    RETURN QUERY
    SELECT
        chapter_record.id,
        chapter_record.chapter_number,
        chapter_record.code,
        chapter_record.title,
        chapter_record.description,
        chapter_record.display_order,
        (SELECT pg_catalog.count(*) FROM public.subject_topics AS topic_record
         WHERE topic_record.chapter_id = chapter_record.id AND topic_record.is_active = true),
        (SELECT pg_catalog.count(*) FROM public.subject_topics AS topic_record
         JOIN public.user_topic_progress AS progress_record
           ON progress_record.topic_id = topic_record.id
          AND progress_record.user_id = v_user_id
          AND progress_record.status = 'completed'
         WHERE topic_record.chapter_id = chapter_record.id AND topic_record.is_active = true),
        COALESCE((
            SELECT pg_catalog.round(pg_catalog.avg(
                COALESCE(progress_record.completion_percentage, 0)
            ), 2)
            FROM public.subject_topics AS topic_record
            LEFT JOIN public.user_topic_progress AS progress_record
              ON progress_record.topic_id = topic_record.id
             AND progress_record.user_id = v_user_id
            WHERE topic_record.chapter_id = chapter_record.id
              AND topic_record.is_active = true
        ), 0)
    FROM public.subject_chapters AS chapter_record
    JOIN public.subject_modules AS module_record
      ON module_record.id = chapter_record.module_id
     AND module_record.subject_id = chapter_record.subject_id
     AND module_record.is_active = true
    JOIN public.subjects AS subject_record
      ON subject_record.id = chapter_record.subject_id
     AND subject_record.is_active = true
    WHERE chapter_record.module_id = p_module_id
      AND chapter_record.is_active = true
    ORDER BY chapter_record.display_order, chapter_record.chapter_number;
END;
$function$;

CREATE FUNCTION public.get_topics_by_chapter(p_chapter_id integer)
RETURNS TABLE (
    topic_id integer,
    topic_number integer,
    topic_code text,
    topic_title text,
    topic_description text,
    estimated_study_minutes integer,
    difficulty_level text,
    display_order integer,
    resource_count bigint,
    flashcard_count bigint,
    progress_status text,
    completion_percentage numeric,
    last_accessed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to view learning topics.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    RETURN QUERY
    SELECT
        topic_record.id,
        topic_record.topic_number,
        topic_record.code,
        topic_record.title,
        topic_record.description,
        topic_record.estimated_study_minutes,
        topic_record.difficulty_level,
        topic_record.display_order,
        (SELECT pg_catalog.count(*) FROM public.learning_resources AS resource_record
         WHERE resource_record.topic_id = topic_record.id AND resource_record.is_active = true),
        (SELECT pg_catalog.count(*) FROM public.flashcards AS flashcard_record
         WHERE flashcard_record.topic_id = topic_record.id AND flashcard_record.is_active = true),
        COALESCE(progress_record.status, 'not_started'),
        COALESCE(progress_record.completion_percentage, 0),
        progress_record.last_accessed_at
    FROM public.subject_topics AS topic_record
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.id = topic_record.chapter_id
     AND chapter_record.module_id = topic_record.module_id
     AND chapter_record.subject_id = topic_record.subject_id
     AND chapter_record.is_active = true
    JOIN public.subject_modules AS module_record
      ON module_record.id = topic_record.module_id
     AND module_record.subject_id = topic_record.subject_id
     AND module_record.is_active = true
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND subject_record.is_active = true
    LEFT JOIN public.user_topic_progress AS progress_record
      ON progress_record.user_id = v_user_id
     AND progress_record.topic_id = topic_record.id
    WHERE topic_record.chapter_id = p_chapter_id
      AND topic_record.is_active = true
    ORDER BY topic_record.display_order, topic_record.topic_number;
END;
$function$;

CREATE FUNCTION public.get_topic_details(p_topic_id integer)
RETURNS TABLE (
    subject_id bigint,
    subject_code text,
    subject_title text,
    module_id integer,
    module_title text,
    chapter_id integer,
    chapter_title text,
    topic_id integer,
    topic_code text,
    topic_title text,
    topic_description text,
    learning_objective text,
    practical_relevance text,
    estimated_study_minutes integer,
    difficulty_level text,
    is_exam_relevant boolean,
    progress_status text,
    completion_percentage numeric,
    total_time_spent_minutes integer,
    is_entitled boolean,
    resource_count bigint,
    flashcard_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to view this learning topic.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    RETURN QUERY
    SELECT
        subject_record.id::bigint,
        subject_record.code,
        subject_record.title,
        module_record.id,
        module_record.title,
        chapter_record.id,
        chapter_record.title,
        topic_record.id,
        topic_record.code,
        topic_record.title,
        topic_record.description,
        topic_record.learning_objective,
        topic_record.practical_relevance,
        topic_record.estimated_study_minutes,
        topic_record.difficulty_level,
        topic_record.is_exam_relevant,
        COALESCE(progress_record.status, 'not_started'),
        COALESCE(progress_record.completion_percentage, 0),
        COALESCE(progress_record.total_time_spent_minutes, 0),
        EXISTS (
            SELECT 1 FROM public.user_entitlements AS entitlement_record
            WHERE entitlement_record.user_id = v_user_id
              AND entitlement_record.subject_id = subject_record.id
              AND entitlement_record.status = 'active'
              AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
              AND (entitlement_record.valid_until IS NULL
                   OR entitlement_record.valid_until > pg_catalog.clock_timestamp())
        ),
        (SELECT pg_catalog.count(*) FROM public.learning_resources AS resource_record
         WHERE resource_record.topic_id = topic_record.id AND resource_record.is_active = true),
        (SELECT pg_catalog.count(*) FROM public.flashcards AS flashcard_record
         WHERE flashcard_record.topic_id = topic_record.id AND flashcard_record.is_active = true)
    FROM public.subject_topics AS topic_record
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.id = topic_record.chapter_id
     AND chapter_record.module_id = topic_record.module_id
     AND chapter_record.subject_id = topic_record.subject_id
     AND chapter_record.is_active = true
    JOIN public.subject_modules AS module_record
      ON module_record.id = topic_record.module_id
     AND module_record.subject_id = topic_record.subject_id
     AND module_record.is_active = true
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND subject_record.is_active = true
    LEFT JOIN public.user_topic_progress AS progress_record
      ON progress_record.user_id = v_user_id
     AND progress_record.topic_id = topic_record.id
    WHERE topic_record.id = p_topic_id
      AND topic_record.is_active = true;
END;
$function$;

CREATE FUNCTION public.get_learning_resources(p_topic_id integer)
RETURNS TABLE (
    resource_id bigint,
    resource_code text,
    resource_title text,
    short_description text,
    resource_type_code text,
    resource_type_name text,
    icon_name text,
    content text,
    external_url text,
    attachment_path text,
    author_name text,
    version_no integer,
    estimated_read_minutes integer,
    display_order integer,
    is_exam_relevant boolean,
    is_premium boolean,
    is_locked boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_subject_id integer;
    v_is_entitled boolean;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to view learning resources.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT topic_record.subject_id
    INTO v_subject_id
    FROM public.subject_topics AS topic_record
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.id = topic_record.chapter_id
     AND chapter_record.module_id = topic_record.module_id
     AND chapter_record.subject_id = topic_record.subject_id
     AND chapter_record.is_active = true
    JOIN public.subject_modules AS module_record
      ON module_record.id = topic_record.module_id
     AND module_record.subject_id = topic_record.subject_id
     AND module_record.is_active = true
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND subject_record.is_active = true
    WHERE topic_record.id = p_topic_id
      AND topic_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The selected topic is not available.';
    END IF;

    v_is_entitled := EXISTS (
        SELECT 1 FROM public.user_entitlements AS entitlement_record
        WHERE entitlement_record.user_id = v_user_id
          AND entitlement_record.subject_id = v_subject_id
          AND entitlement_record.status = 'active'
          AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
          AND (entitlement_record.valid_until IS NULL
               OR entitlement_record.valid_until > pg_catalog.clock_timestamp())
    );

    RETURN QUERY
    SELECT
        resource_record.id::bigint,
        resource_record.code,
        resource_record.title,
        resource_record.short_description,
        resource_type_record.code,
        resource_type_record.name,
        resource_type_record.icon_name,
        CASE WHEN resource_record.is_premium AND NOT v_is_entitled
             THEN NULL ELSE resource_record.content END,
        CASE WHEN resource_record.is_premium AND NOT v_is_entitled
             THEN NULL ELSE resource_record.external_url END,
        CASE WHEN resource_record.is_premium AND NOT v_is_entitled
             THEN NULL ELSE resource_record.attachment_path END,
        resource_record.author_name,
        resource_record.version_no,
        resource_record.estimated_read_minutes,
        resource_record.display_order,
        resource_record.is_exam_relevant,
        resource_record.is_premium,
        resource_record.is_premium AND NOT v_is_entitled
    FROM public.learning_resources AS resource_record
    JOIN public.learning_resource_types AS resource_type_record
      ON resource_type_record.id = resource_record.resource_type_id
     AND resource_type_record.is_active = true
    WHERE resource_record.topic_id = p_topic_id
      AND resource_record.subject_id = v_subject_id
      AND resource_record.is_active = true
    ORDER BY resource_record.display_order, resource_record.id;
END;
$function$;

CREATE FUNCTION public.get_flashcards(p_topic_id integer)
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
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT topic_record.subject_id INTO v_subject_id
    FROM public.subject_topics AS topic_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND subject_record.is_active = true
    WHERE topic_record.id = p_topic_id AND topic_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The selected topic is not available.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.user_entitlements AS entitlement_record
        WHERE entitlement_record.user_id = v_user_id
          AND entitlement_record.subject_id = v_subject_id
          AND entitlement_record.status = 'active'
          AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
          AND (entitlement_record.valid_until IS NULL
               OR entitlement_record.valid_until > pg_catalog.clock_timestamp())
    ) THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Active subject access is required for flashcards.';
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

CREATE FUNCTION public.record_learning_activity(
    p_topic_id integer,
    p_activity_type text,
    p_reference_id bigint DEFAULT NULL,
    p_duration_seconds integer DEFAULT 0,
    p_completion_percentage numeric DEFAULT NULL
)
RETURNS TABLE (
    activity_id bigint,
    progress_status text,
    completion_percentage numeric,
    total_time_spent_minutes integer,
    completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_subject_id integer;
    v_module_id integer;
    v_chapter_id integer;
    v_activity_type text := pg_catalog.lower(pg_catalog.btrim(p_activity_type));
    v_has_entitlement boolean;
    v_status text;
    v_completion numeric;
    v_added_minutes integer;
    v_activity_id bigint;
    v_progress public.user_topic_progress;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in before recording learning progress.';
    END IF;

    PERFORM 1 FROM public.profiles AS profile_record
    WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    IF v_activity_type IS NULL OR v_activity_type NOT IN (
        'topic_started', 'topic_completed', 'resource_viewed',
        'flashcard_reviewed', 'note_viewed', 'revision_completed'
    ) THEN
        RAISE EXCEPTION 'Select a supported learning activity type.';
    END IF;
    IF COALESCE(p_duration_seconds, 0) < 0
       OR COALESCE(p_duration_seconds, 0) > 86400 THEN
        RAISE EXCEPTION 'Learning duration must be between 0 and 86400 seconds.';
    END IF;
    IF p_completion_percentage IS NOT NULL
       AND (p_completion_percentage < 0 OR p_completion_percentage > 100) THEN
        RAISE EXCEPTION 'Completion percentage must be between 0 and 100.';
    END IF;

    SELECT topic_record.subject_id, topic_record.module_id, topic_record.chapter_id
    INTO v_subject_id, v_module_id, v_chapter_id
    FROM public.subject_topics AS topic_record
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.id = topic_record.chapter_id
     AND chapter_record.module_id = topic_record.module_id
     AND chapter_record.subject_id = topic_record.subject_id
     AND chapter_record.is_active = true
    JOIN public.subject_modules AS module_record
      ON module_record.id = topic_record.module_id
     AND module_record.subject_id = topic_record.subject_id
     AND module_record.is_active = true
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND subject_record.is_active = true
    WHERE topic_record.id = p_topic_id AND topic_record.is_active = true;
    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The selected topic is not available.';
    END IF;

    v_has_entitlement := EXISTS (
        SELECT 1 FROM public.user_entitlements AS entitlement_record
        WHERE entitlement_record.user_id = v_user_id
          AND entitlement_record.subject_id = v_subject_id
          AND entitlement_record.status = 'active'
          AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
          AND (entitlement_record.valid_until IS NULL
               OR entitlement_record.valid_until > pg_catalog.clock_timestamp())
    );

    IF v_activity_type IN ('resource_viewed', 'note_viewed') THEN
        IF p_reference_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.learning_resources AS resource_record
            WHERE resource_record.id = p_reference_id
              AND resource_record.topic_id = p_topic_id
              AND resource_record.subject_id = v_subject_id
              AND resource_record.is_active = true
              AND (resource_record.is_premium = false OR v_has_entitlement)
        ) THEN
            RAISE EXCEPTION 'The selected learning resource is not available.';
        END IF;
    ELSIF v_activity_type = 'flashcard_reviewed' THEN
        IF NOT v_has_entitlement THEN
            RAISE SQLSTATE 'PT403'
                USING MESSAGE = 'Active subject access is required for flashcards.';
        END IF;
        IF p_reference_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.flashcards AS flashcard_record
            WHERE flashcard_record.id = p_reference_id
              AND flashcard_record.topic_id = p_topic_id
              AND flashcard_record.subject_id = v_subject_id
              AND flashcard_record.is_active = true
        ) THEN
            RAISE EXCEPTION 'The selected flashcard is not available.';
        END IF;
    ELSE
        IF p_reference_id IS NOT NULL THEN
            RAISE EXCEPTION 'This activity type does not accept a reference ID.';
        END IF;
        IF NOT v_has_entitlement AND NOT EXISTS (
            SELECT 1 FROM public.learning_resources AS resource_record
            WHERE resource_record.topic_id = p_topic_id
              AND resource_record.is_active = true
              AND resource_record.is_premium = false
        ) THEN
            RAISE SQLSTATE 'PT403'
                USING MESSAGE = 'Active subject access is required for this topic.';
        END IF;
    END IF;

    v_status := CASE
        WHEN v_activity_type IN ('topic_completed', 'revision_completed')
            THEN 'completed'
        ELSE 'in_progress'
    END;
    v_completion := CASE
        WHEN v_status = 'completed' THEN 100
        ELSE COALESCE(p_completion_percentage, 0)
    END;
    v_added_minutes := COALESCE(p_duration_seconds, 0) / 60;

    INSERT INTO public.user_topic_progress (
        user_id, topic_id, status, completion_percentage,
        total_time_spent_minutes, last_accessed_at, completed_at
    ) VALUES (
        v_user_id, p_topic_id, v_status, v_completion,
        v_added_minutes, pg_catalog.clock_timestamp(),
        CASE WHEN v_status = 'completed' THEN pg_catalog.clock_timestamp() END
    )
    ON CONFLICT (user_id, topic_id) DO UPDATE SET
        status = CASE
            WHEN public.user_topic_progress.status = 'completed'
                THEN 'completed'
            ELSE EXCLUDED.status
        END,
        completion_percentage = CASE
            WHEN public.user_topic_progress.status = 'completed'
                 OR EXCLUDED.status = 'completed' THEN 100
            ELSE pg_catalog.greatest(
                COALESCE(public.user_topic_progress.completion_percentage, 0),
                COALESCE(EXCLUDED.completion_percentage, 0)
            )
        END,
        total_time_spent_minutes =
            COALESCE(public.user_topic_progress.total_time_spent_minutes, 0)
            + COALESCE(EXCLUDED.total_time_spent_minutes, 0),
        last_accessed_at = pg_catalog.clock_timestamp(),
        completed_at = CASE
            WHEN public.user_topic_progress.status = 'completed'
                THEN public.user_topic_progress.completed_at
            WHEN EXCLUDED.status = 'completed'
                THEN pg_catalog.clock_timestamp()
            ELSE NULL
        END,
        updated_at = pg_catalog.clock_timestamp()
    RETURNING * INTO v_progress;

    INSERT INTO public.user_learning_activity (
        user_id, subject_id, module_id, chapter_id, topic_id,
        activity_type, reference_id, activity_time, duration_seconds, remarks
    ) VALUES (
        v_user_id, v_subject_id, v_module_id, v_chapter_id, p_topic_id,
        v_activity_type, p_reference_id, pg_catalog.clock_timestamp(),
        COALESCE(p_duration_seconds, 0), 'learning_module_rpc'
    ) RETURNING id INTO v_activity_id;

    RETURN QUERY SELECT
        v_activity_id,
        v_progress.status,
        v_progress.completion_percentage,
        v_progress.total_time_spent_minutes,
        v_progress.completed_at;
END;
$function$;

CREATE FUNCTION public.get_resume_learning(p_subject_id bigint DEFAULT NULL)
RETURNS TABLE (
    subject_id bigint,
    subject_code text,
    subject_title text,
    module_id integer,
    module_title text,
    chapter_id integer,
    chapter_title text,
    topic_id integer,
    topic_title text,
    progress_status text,
    completion_percentage numeric,
    last_accessed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to resume learning.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN RAISE EXCEPTION 'Your account is not active.'; END IF;

    RETURN QUERY
    SELECT
        subject_record.id::bigint, subject_record.code, subject_record.title,
        module_record.id, module_record.title,
        chapter_record.id, chapter_record.title,
        topic_record.id, topic_record.title,
        progress_record.status, progress_record.completion_percentage,
        progress_record.last_accessed_at
    FROM public.user_topic_progress AS progress_record
    JOIN public.subject_topics AS topic_record
      ON topic_record.id = progress_record.topic_id AND topic_record.is_active = true
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.id = topic_record.chapter_id AND chapter_record.is_active = true
    JOIN public.subject_modules AS module_record
      ON module_record.id = topic_record.module_id AND module_record.is_active = true
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id AND subject_record.is_active = true
    WHERE progress_record.user_id = v_user_id
      AND progress_record.status <> 'completed'
      AND (p_subject_id IS NULL OR subject_record.id = p_subject_id)
      AND (
          EXISTS (
              SELECT 1 FROM public.user_entitlements AS entitlement_record
              WHERE entitlement_record.user_id = v_user_id
                AND entitlement_record.subject_id = subject_record.id
                AND entitlement_record.status = 'active'
                AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
                AND (entitlement_record.valid_until IS NULL
                     OR entitlement_record.valid_until > pg_catalog.clock_timestamp())
          )
          OR EXISTS (
              SELECT 1 FROM public.learning_resources AS resource_record
              WHERE resource_record.topic_id = topic_record.id
                AND resource_record.is_active = true
                AND resource_record.is_premium = false
          )
      )
    ORDER BY progress_record.last_accessed_at DESC NULLS LAST, progress_record.id DESC
    LIMIT 1;
END;
$function$;

CREATE FUNCTION public.get_recent_activity(p_limit integer DEFAULT 10)
RETURNS TABLE (
    activity_id bigint,
    activity_type text,
    activity_time timestamptz,
    duration_seconds integer,
    subject_id bigint,
    subject_code text,
    subject_title text,
    topic_id integer,
    topic_title text,
    reference_id bigint,
    reference_title text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to view recent learning activity.'; END IF;
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 50 THEN
        RAISE EXCEPTION 'Activity limit must be between 1 and 50.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN RAISE EXCEPTION 'Your account is not active.'; END IF;

    RETURN QUERY
    SELECT
        activity_record.id,
        activity_record.activity_type,
        activity_record.activity_time,
        activity_record.duration_seconds,
        subject_record.id::bigint,
        subject_record.code,
        subject_record.title,
        topic_record.id,
        topic_record.title,
        activity_record.reference_id,
        CASE
            WHEN activity_record.activity_type IN ('resource_viewed', 'note_viewed')
                THEN resource_record.title
            WHEN activity_record.activity_type = 'flashcard_reviewed'
                THEN flashcard_record.code
            ELSE topic_record.title
        END
    FROM public.user_learning_activity AS activity_record
    LEFT JOIN public.subjects AS subject_record
      ON subject_record.id = activity_record.subject_id
    LEFT JOIN public.subject_topics AS topic_record
      ON topic_record.id = activity_record.topic_id
    LEFT JOIN public.learning_resources AS resource_record
      ON resource_record.id = activity_record.reference_id
     AND activity_record.activity_type IN ('resource_viewed', 'note_viewed')
    LEFT JOIN public.flashcards AS flashcard_record
      ON flashcard_record.id = activity_record.reference_id
     AND activity_record.activity_type = 'flashcard_reviewed'
    WHERE activity_record.user_id = v_user_id
    ORDER BY activity_record.activity_time DESC, activity_record.id DESC
    LIMIT p_limit;
END;
$function$;

CREATE FUNCTION public.get_topic_completion(p_topic_id integer)
RETURNS TABLE (
    topic_id integer,
    progress_status text,
    completion_percentage numeric,
    total_time_spent_minutes integer,
    last_accessed_at timestamptz,
    completed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to view topic progress.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN RAISE EXCEPTION 'Your account is not active.'; END IF;

    RETURN QUERY
    SELECT
        topic_record.id,
        COALESCE(progress_record.status, 'not_started'),
        COALESCE(progress_record.completion_percentage, 0),
        COALESCE(progress_record.total_time_spent_minutes, 0),
        progress_record.last_accessed_at,
        progress_record.completed_at
    FROM public.subject_topics AS topic_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id AND subject_record.is_active = true
    LEFT JOIN public.user_topic_progress AS progress_record
      ON progress_record.user_id = v_user_id AND progress_record.topic_id = topic_record.id
    WHERE topic_record.id = p_topic_id AND topic_record.is_active = true;
END;
$function$;

CREATE FUNCTION public.get_learning_statistics(p_subject_id bigint)
RETURNS TABLE (
    subject_id bigint,
    total_topics bigint,
    started_topics bigint,
    completed_topics bigint,
    completion_percentage numeric,
    total_time_spent_minutes bigint,
    activity_count bigint,
    last_learning_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to view learning statistics.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN RAISE EXCEPTION 'Your account is not active.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.subjects AS subject_record
        WHERE subject_record.id = p_subject_id AND subject_record.is_active = true
    ) THEN RAISE EXCEPTION 'The selected subject is not available.'; END IF;

    RETURN QUERY
    SELECT
        p_subject_id,
        pg_catalog.count(topic_record.id),
        pg_catalog.count(progress_record.id)
            FILTER (WHERE progress_record.status IN ('in_progress', 'completed')),
        pg_catalog.count(progress_record.id)
            FILTER (WHERE progress_record.status = 'completed'),
        COALESCE(pg_catalog.round(pg_catalog.avg(
            COALESCE(progress_record.completion_percentage, 0)
        ), 2), 0),
        COALESCE(pg_catalog.sum(progress_record.total_time_spent_minutes), 0)::bigint,
        (SELECT pg_catalog.count(*) FROM public.user_learning_activity AS activity_record
         WHERE activity_record.user_id = v_user_id
           AND activity_record.subject_id = p_subject_id),
        (SELECT pg_catalog.max(activity_record.activity_time)
         FROM public.user_learning_activity AS activity_record
         WHERE activity_record.user_id = v_user_id
           AND activity_record.subject_id = p_subject_id)
    FROM public.subject_topics AS topic_record
    LEFT JOIN public.user_topic_progress AS progress_record
      ON progress_record.user_id = v_user_id
     AND progress_record.topic_id = topic_record.id
    WHERE topic_record.subject_id = p_subject_id
      AND topic_record.is_active = true;
END;
$function$;

-- Preserve the legacy signature while closing its audited cross-user and
-- anonymous-execution vulnerability. Progress never regresses.
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
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_subject_id integer;
    v_progress public.user_topic_progress;
BEGIN
    IF v_user_id IS NULL OR p_user_id IS DISTINCT FROM v_user_id THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Progress can be updated only for the signed-in learner.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id AND profile_record.status = 'active'
    ) THEN RAISE EXCEPTION 'Your account is not active.'; END IF;
    IF p_status IS NULL
       OR p_status NOT IN ('not_started', 'in_progress', 'completed') THEN
        RAISE EXCEPTION 'Invalid progress status.';
    END IF;
    IF p_completion_percentage IS NULL
       OR p_completion_percentage < 0
       OR p_completion_percentage > 100 THEN
        RAISE EXCEPTION 'Completion percentage must be between 0 and 100.';
    END IF;
    IF p_status = 'completed' AND p_completion_percentage <> 100 THEN
        RAISE EXCEPTION 'Completed progress must be 100 percent.';
    END IF;
    IF COALESCE(p_time_spent_minutes, 0) < 0
       OR COALESCE(p_time_spent_minutes, 0) > 1440 THEN
        RAISE EXCEPTION 'Learning time must be between 0 and 1440 minutes.';
    END IF;

    SELECT topic_record.subject_id INTO v_subject_id
    FROM public.subject_topics AS topic_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id AND subject_record.is_active = true
    WHERE topic_record.id = p_topic_id AND topic_record.is_active = true;
    IF v_subject_id IS NULL THEN RAISE EXCEPTION 'The selected topic is not available.'; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.user_entitlements AS entitlement_record
        WHERE entitlement_record.user_id = v_user_id
          AND entitlement_record.subject_id = v_subject_id
          AND entitlement_record.status = 'active'
          AND entitlement_record.valid_from <= pg_catalog.clock_timestamp()
          AND (entitlement_record.valid_until IS NULL
               OR entitlement_record.valid_until > pg_catalog.clock_timestamp())
    ) AND NOT EXISTS (
        SELECT 1 FROM public.learning_resources AS resource_record
        WHERE resource_record.topic_id = p_topic_id
          AND resource_record.is_active = true
          AND resource_record.is_premium = false
    ) THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Active subject access is required for this topic.';
    END IF;

    INSERT INTO public.user_topic_progress (
        user_id, topic_id, status, completion_percentage,
        total_time_spent_minutes, last_accessed_at, completed_at
    ) VALUES (
        v_user_id, p_topic_id, p_status, p_completion_percentage,
        COALESCE(p_time_spent_minutes, 0), pg_catalog.clock_timestamp(),
        CASE WHEN p_status = 'completed' THEN pg_catalog.clock_timestamp() END
    )
    ON CONFLICT (user_id, topic_id) DO UPDATE SET
        status = CASE
            WHEN public.user_topic_progress.status = 'completed'
                THEN 'completed' ELSE EXCLUDED.status END,
        completion_percentage = pg_catalog.greatest(
            COALESCE(public.user_topic_progress.completion_percentage, 0),
            COALESCE(EXCLUDED.completion_percentage, 0)
        ),
        total_time_spent_minutes =
            COALESCE(public.user_topic_progress.total_time_spent_minutes, 0)
            + COALESCE(EXCLUDED.total_time_spent_minutes, 0),
        last_accessed_at = pg_catalog.clock_timestamp(),
        completed_at = CASE
            WHEN public.user_topic_progress.status = 'completed'
                THEN public.user_topic_progress.completed_at
            WHEN EXCLUDED.status = 'completed'
                THEN pg_catalog.clock_timestamp()
            ELSE NULL END,
        updated_at = pg_catalog.clock_timestamp()
    RETURNING * INTO v_progress;
    RETURN v_progress;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_subject_hierarchy(bigint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_modules_by_subject(bigint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_chapters_by_module(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_topics_by_chapter(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_topic_details(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_learning_resources(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_flashcards(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.record_learning_activity(integer, text, bigint, integer, numeric) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_resume_learning(bigint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_recent_activity(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_topic_completion(integer) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_learning_statistics(bigint) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.upsert_user_topic_progress(uuid, integer, text, numeric, integer) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_subject_hierarchy(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_modules_by_subject(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chapters_by_module(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_topics_by_chapter(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_topic_details(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_learning_resources(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_flashcards(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_learning_activity(integer, text, bigint, integer, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_resume_learning(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_recent_activity(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_topic_completion(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_learning_statistics(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_user_topic_progress(uuid, integer, text, numeric, integer) TO authenticated;

COMMENT ON FUNCTION public.record_learning_activity(integer, text, bigint, integer, numeric) IS
    'Records one owned Learning event and monotonically updates topic progress. resource_viewed/note_viewed reference learning_resources.id; flashcard_reviewed references flashcards.id; topic/revision events use NULL.';
COMMENT ON FUNCTION public.get_learning_resources(integer) IS
    'Returns active topic resources while redacting premium payload fields unless the learner has a current subject entitlement.';

COMMIT;
