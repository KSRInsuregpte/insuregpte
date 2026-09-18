-- Rebalance correct-answer positions for the 30 active advanced demo rows.
-- This changes only option positions. The option text and correct_option text
-- remain unchanged, so server-side scoring is preserved.

DO $migration$
DECLARE
    v_question record;
    v_options text[];
    v_rotated text[];
    v_current_position integer;
    v_target_position integer;
    v_index integer;
    v_subject_row integer;
BEGIN
    FOR v_question IN
        SELECT
            q.id,
            q.correct_option,
            q.option_a,
            q.option_b,
            q.option_c,
            q.option_d,
            s.code AS subject_code,
            ROW_NUMBER() OVER (
                PARTITION BY s.code
                ORDER BY q.id
            )::integer AS subject_row
        FROM public.questions AS q
        JOIN public.subjects AS s ON s.id = q.subject_id
        WHERE s.code IN ('IC01', 'IC11', 'IC14')
          AND q.is_active = true
          AND q.difficulty_level = 'advanced'
        ORDER BY s.code, q.id
    LOOP
        v_options := ARRAY[
            v_question.option_a,
            v_question.option_b,
            v_question.option_c,
            v_question.option_d
        ];

        v_current_position := array_position(
            v_options,
            v_question.correct_option
        );

        IF v_current_position IS NULL THEN
            RAISE EXCEPTION
                'Question % has a correct answer that does not match an option.',
                v_question.id;
        END IF;

        -- Ten questions per subject become A/B/C/D = 3/3/2/2.
        v_subject_row := v_question.subject_row;
        v_target_position := ((v_subject_row - 1) % 4) + 1;
        v_rotated := ARRAY[]::text[];

        FOR v_index IN 1..4 LOOP
            v_rotated := array_append(
                v_rotated,
                v_options[
                    ((v_index - v_target_position + v_current_position - 1 + 400) % 4) + 1
                ]
            );
        END LOOP;

        UPDATE public.questions
        SET option_a = v_rotated[1],
            option_b = v_rotated[2],
            option_c = v_rotated[3],
            option_d = v_rotated[4]
        WHERE id = v_question.id;
    END LOOP;
END;
$migration$;

NOTIFY pgrst, 'reload schema';
