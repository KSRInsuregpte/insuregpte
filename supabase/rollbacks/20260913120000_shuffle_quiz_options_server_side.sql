-- Restore the pre-shuffle question RPC.
CREATE OR REPLACE FUNCTION public.get_attempt_questions(p_attempt_id uuid)
RETURNS TABLE (
    attempt_id uuid, attempt_number integer, test_mode text,
    total_questions integer, time_limit_minutes integer, feedback_mode text,
    started_at timestamptz, question_id bigint, question_order integer,
    question_text text, option_a text, option_b text, option_c text, option_d text
)
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $function$
    SELECT qa.id, qa.attempt_number, qa.test_mode, qa.total_questions,
        qa.time_limit_minutes, qa.feedback_mode, qa.started_at,
        q.id, aq.question_order, q.question_text,
        q.option_a, q.option_b, q.option_c, q.option_d
    FROM public.quiz_attempts AS qa
    JOIN public.quiz_attempt_questions AS aq ON aq.attempt_id = qa.id
    JOIN public.questions AS q ON q.id = aq.question_id
    WHERE qa.id = p_attempt_id AND qa.user_id = auth.uid()
      AND qa.status = 'in_progress'
    ORDER BY aq.question_order;
$function$;
REVOKE ALL ON FUNCTION public.get_attempt_questions(uuid)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_attempt_questions(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
