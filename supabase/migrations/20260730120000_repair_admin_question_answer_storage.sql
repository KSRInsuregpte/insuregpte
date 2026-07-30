-- Restore the existing quiz-engine correct-answer storage contract for
-- questions created or edited through the administrator portal.
--
-- The quiz frontend submits the selected option text and
-- submit_quiz_answer(uuid,bigint,text) compares that text with
-- questions.correct_option. The original admin RPC incorrectly stored the
-- option tag (A, B, C, or D) in that column.
--
-- This migration:
--   1. reuses the existing questions and admin_audit_events tables;
--   2. preserves the admin_save_question(jsonb) signature;
--   3. repairs only tagged rows that have an administrator audit event; and
--   4. stores the selected option's full text on every future admin save.
--
-- Safe operational rollback:
--   supabase/rollbacks/
--     20260730120000_repair_admin_question_answer_storage.sql

BEGIN;

DO $guard$
BEGIN
    IF pg_catalog.to_regclass('public.questions') IS NULL
       OR pg_catalog.to_regclass('public.admin_audit_events') IS NULL THEN
        RAISE EXCEPTION
            'Deploy the question bank and administrator portal before this repair.';
    END IF;

    IF pg_catalog.to_regprocedure(
        'public.admin_save_question(jsonb)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'The existing admin_save_question(jsonb) RPC is missing.';
    END IF;

    IF pg_catalog.to_regprocedure(
        'public.submit_quiz_answer(uuid,bigint,text)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'The existing submit_quiz_answer(uuid,bigint,text) RPC is missing.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.questions AS question_record
        WHERE pg_catalog.upper(
            pg_catalog.btrim(question_record.correct_option)
        ) IN ('A', 'B', 'C', 'D')
          AND EXISTS (
              SELECT 1
              FROM public.admin_audit_events AS audit_event
              WHERE audit_event.entity_type = 'question'
                AND audit_event.entity_key = question_record.id::text
          )
          AND (
              NULLIF(
                  pg_catalog.btrim(question_record.option_a),
                  ''
              ) IS NULL
              OR NULLIF(
                  pg_catalog.btrim(question_record.option_b),
                  ''
              ) IS NULL
              OR NULLIF(
                  pg_catalog.btrim(question_record.option_c),
                  ''
              ) IS NULL
              OR NULLIF(
                  pg_catalog.btrim(question_record.option_d),
                  ''
              ) IS NULL
          )
    ) THEN
        RAISE EXCEPTION
            'A tagged administrator-edited question has an empty answer option; review it before repairing.';
    END IF;
END;
$guard$;

-- Normalize only rows known to have passed through the administrator RPC.
-- The audit event is the provenance boundary that prevents a broad rewrite of
-- any legacy question whose genuine answer text might be a single letter.
UPDATE public.questions AS question_record
SET correct_option = CASE pg_catalog.upper(
        pg_catalog.btrim(question_record.correct_option)
    )
        WHEN 'A' THEN question_record.option_a
        WHEN 'B' THEN question_record.option_b
        WHEN 'C' THEN question_record.option_c
        WHEN 'D' THEN question_record.option_d
    END,
    updated_at = pg_catalog.clock_timestamp()
WHERE pg_catalog.upper(
        pg_catalog.btrim(question_record.correct_option)
    ) IN ('A', 'B', 'C', 'D')
  AND EXISTS (
      SELECT 1
      FROM public.admin_audit_events AS audit_event
      WHERE audit_event.entity_type = 'question'
        AND audit_event.entity_key = question_record.id::text
  );

CREATE OR REPLACE FUNCTION public.admin_save_question(p_question jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_question_id integer :=
        NULLIF(p_question ->> 'id', '')::integer;
    v_subject_id integer :=
        NULLIF(p_question ->> 'subject_id', '')::integer;
    v_question_text text :=
        BTRIM(COALESCE(p_question ->> 'question_text', ''));
    v_option_a text := BTRIM(COALESCE(p_question ->> 'option_a', ''));
    v_option_b text := BTRIM(COALESCE(p_question ->> 'option_b', ''));
    v_option_c text := BTRIM(COALESCE(p_question ->> 'option_c', ''));
    v_option_d text := BTRIM(COALESCE(p_question ->> 'option_d', ''));
    v_correct_option text :=
        UPPER(BTRIM(COALESCE(p_question ->> 'correct_option', '')));
    v_correct_answer text;
    v_explanation text :=
        BTRIM(COALESCE(p_question ->> 'explanation', ''));
    v_requested_difficulty text :=
        LOWER(BTRIM(COALESCE(p_question ->> 'difficulty_level', '')));
    v_difficulty_level text;
    v_marks numeric :=
        COALESCE(NULLIF(p_question ->> 'marks', '')::numeric, 1);
    v_negative_marks numeric :=
        COALESCE(NULLIF(p_question ->> 'negative_marks', '')::numeric, 0);
    v_display_order integer :=
        COALESCE(NULLIF(p_question ->> 'display_order', '')::integer, 1);
    v_is_active boolean :=
        COALESCE((p_question ->> 'is_active')::boolean, true);
    v_action text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    v_difficulty_level := CASE v_requested_difficulty
        WHEN 'easy' THEN 'foundation'
        WHEN 'moderate' THEN 'intermediate'
        WHEN 'hard' THEN 'advanced'
        WHEN 'foundation' THEN 'foundation'
        WHEN 'intermediate' THEN 'intermediate'
        WHEN 'advanced' THEN 'advanced'
        ELSE NULL
    END;

    IF v_subject_id IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM public.subjects AS subject_record
           WHERE subject_record.id = v_subject_id
       ) THEN
        RAISE EXCEPTION 'Select an available subject.';
    END IF;
    IF CHAR_LENGTH(v_question_text) NOT BETWEEN 10 AND 5000 THEN
        RAISE EXCEPTION
            'Question text must contain between 10 and 5000 characters.';
    END IF;
    IF LEAST(
        CHAR_LENGTH(v_option_a),
        CHAR_LENGTH(v_option_b),
        CHAR_LENGTH(v_option_c),
        CHAR_LENGTH(v_option_d)
    ) < 1 THEN
        RAISE EXCEPTION 'All four answer options are required.';
    END IF;
    IF v_option_a = v_option_b
       OR v_option_a = v_option_c
       OR v_option_a = v_option_d
       OR v_option_b = v_option_c
       OR v_option_b = v_option_d
       OR v_option_c = v_option_d THEN
        RAISE EXCEPTION 'Answer options must be different from one another.';
    END IF;
    IF v_correct_option NOT IN ('A', 'B', 'C', 'D') THEN
        RAISE EXCEPTION 'Select the correct answer from A, B, C, or D.';
    END IF;

    -- Keep the existing quiz-engine contract: correct_option stores the full
    -- answer text, while the admin request may use an A/B/C/D form tag.
    v_correct_answer := CASE v_correct_option
        WHEN 'A' THEN v_option_a
        WHEN 'B' THEN v_option_b
        WHEN 'C' THEN v_option_c
        WHEN 'D' THEN v_option_d
    END;

    IF CHAR_LENGTH(v_explanation) NOT BETWEEN 5 AND 10000 THEN
        RAISE EXCEPTION
            'Add an explanation containing at least 5 characters.';
    END IF;
    IF v_difficulty_level IS NULL THEN
        RAISE EXCEPTION 'Select Easy, Moderate, or Hard difficulty.';
    END IF;
    IF v_marks <= 0 OR v_negative_marks < 0 THEN
        RAISE EXCEPTION
            'Marks must be positive and negative marks cannot be below zero.';
    END IF;
    IF v_display_order < 1 THEN
        RAISE EXCEPTION 'Display order must be at least 1.';
    END IF;

    IF v_question_id IS NULL THEN
        INSERT INTO public.questions (
            subject_id,
            question_text,
            correct_option,
            explanation,
            option_a,
            option_b,
            option_c,
            option_d,
            difficulty_level,
            question_type,
            marks,
            negative_marks,
            display_order,
            is_active
        )
        VALUES (
            v_subject_id,
            v_question_text,
            v_correct_answer,
            v_explanation,
            v_option_a,
            v_option_b,
            v_option_c,
            v_option_d,
            v_difficulty_level,
            'MCQ',
            v_marks,
            v_negative_marks,
            v_display_order,
            v_is_active
        )
        RETURNING id INTO v_question_id;

        v_action := 'create';
    ELSE
        UPDATE public.questions AS question_record
        SET subject_id = v_subject_id,
            question_text = v_question_text,
            correct_option = v_correct_answer,
            explanation = v_explanation,
            option_a = v_option_a,
            option_b = v_option_b,
            option_c = v_option_c,
            option_d = v_option_d,
            difficulty_level = v_difficulty_level,
            question_type = 'MCQ',
            marks = v_marks,
            negative_marks = v_negative_marks,
            display_order = v_display_order,
            is_active = v_is_active,
            updated_at = clock_timestamp()
        WHERE question_record.id = v_question_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'The selected question was not found.';
        END IF;

        v_action := 'update';
    END IF;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        v_action,
        'question',
        v_question_id::text,
        jsonb_build_object(
            'subject_id', v_subject_id,
            'difficulty_level', v_difficulty_level,
            'is_active', v_is_active
        )
    );

    RETURN v_question_id::bigint;
END;
$function$;

ALTER FUNCTION public.admin_save_question(jsonb) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.admin_save_question(jsonb)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.admin_save_question(jsonb)
TO authenticated;

COMMENT ON FUNCTION public.admin_save_question(jsonb) IS
    'Creates or updates current MCQ records, maps display difficulty labels, and stores the selected answer option text required by quiz scoring.';

NOTIFY pgrst, 'reload schema';

COMMIT;
