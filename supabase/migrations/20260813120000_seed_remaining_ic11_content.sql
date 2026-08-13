-- Complete IC11 Chapters 2-9 with original structured learning resources.
-- Each of the remaining 39 topics receives a learning note, revision note,
-- and three flashcards. The accepted Chapter 1 content is not changed.
-- No learner, progress, entitlement, activity, or practice-attempt rows are changed.

BEGIN;

DROP TABLE IF EXISTS pg_temp.ic11_remaining_content_seed;

CREATE TEMPORARY TABLE ic11_remaining_content_seed (
    topic_code text PRIMARY KEY,
    learning_focus text NOT NULL,
    study_method text NOT NULL,
    exam_focus text NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO ic11_remaining_content_seed VALUES
('IC11-C02-T01', 'market evolution; public and private insurers; specialised participants; regulatory structure; market segmentation', 'Build a timeline, then group institutions by the insurance function they perform.', 'Explain the market structure and distinguish insurer, regulator and specialised institution.'),
('IC11-C02-T02', 'general insurers; standalone health insurers; reinsurers; agriculture insurance; export credit; government insurance arrangements', 'Compare each institution by ownership, customer, risk class and source of capacity.', 'Match an institution to its principal purpose and identify when specialist capacity is needed.'),
('IC11-C02-T03', 'agents; corporate agents; brokers; third-party administrators; surveyors; loss assessors', 'Use a responsibility matrix covering solicitation, advice, servicing, administration and loss assessment.', 'Distinguish intermediary roles and avoid assigning a regulated function to the wrong participant.'),
('IC11-C02-T04', 'international insurance centres; Lloyd''s market; global insurers; reinsurers; cross-border capacity; complex risks', 'Trace a large risk from the Indian insured through local placement to international capacity.', 'Explain why international insurance and reinsurance markets support large or specialised risks.'),

('IC11-C03-T01', 'offer and acceptance; consideration; capacity; legality; utmost good faith; policy components', 'Review a policy from contract formation through operative clause, exclusions, conditions and schedule.', 'Identify the elements of an insurance contract and the function of the main policy sections.'),
('IC11-C03-T02', 'proposal form; material facts; disclosure; declarations; underwriting evidence; consequences of misstatement', 'Separate facts that describe the risk from statements that form contractual declarations.', 'Explain why material information affects acceptance, terms and claim disputes.'),
('IC11-C03-T03', 'cover note; certificate; schedule; endorsement; interim evidence; amendment of cover', 'Arrange the documents in the order they may appear during placement and servicing.', 'Distinguish evidence of temporary cover, statutory certification and a formal policy amendment.'),
('IC11-C03-T04', 'policy interpretation; ordinary meaning; ambiguity; warranties; conditions; exceptions; co-insurance; document control', 'Read the policy as a whole and reconcile the schedule, wording and endorsements before reaching a conclusion.', 'Apply a disciplined interpretation method and explain how co-insurance participation is documented.'),

('IC11-C04-T01', 'insured property; insured perils; exclusions; sum insured; average; deductible; indemnity', 'Map the insured property against the operative perils and then test every applicable limitation.', 'Explain the structure of standard fire cover and the effect of underinsurance.'),
('IC11-C04-T02', 'extensions; add-on covers; declarations; floater arrangements; reinstatement value; special policies', 'Start with the basic gap and select the extension or policy structure that addresses it.', 'Choose an appropriate adaptation for changing stock, multiple locations or special valuation needs.'),
('IC11-C04-T03', 'material damage proviso; gross profit; standing charges; increased cost of working; indemnity period; trends', 'Follow a loss from physical damage through interruption, recovery time and financial calculation.', 'Distinguish material damage from consequential loss and explain the importance of the indemnity period.'),
('IC11-C04-T04', 'cargo interest; transit; Institute Cargo Clauses; valuation; insurable interest; documents; recovery rights', 'Trace goods from origin to destination and identify when risk, title and insurance responsibility change.', 'Compare levels of cargo cover and identify the documents needed for a transit claim.'),
('IC11-C04-T05', 'hull interest; maritime perils; time and voyage policies; valued policies; collision liability; total loss', 'Classify the marine interest first, then select the policy form and relevant maritime risks.', 'Distinguish hull from cargo insurance and compare time, voyage and valued arrangements.'),

('IC11-C05-T01', 'vehicle classification; compulsory third-party liability; own damage; package cover; rating; motor claims', 'Separate statutory liability, vehicle damage and personal benefits before reviewing policy response.', 'Distinguish compulsory and optional motor protection and outline the motor claim process.'),
('IC11-C05-T02', 'public liability; product liability; employer liability; professional negligence; claims-made cover; limits', 'Identify the duty, alleged breach, claimant, injury or damage, and the policy trigger.', 'Match common liability exposures with suitable cover and distinguish occurrence from claims-made features.'),
('IC11-C05-T03', 'accidental death; disability; medical expenses; hospitalisation; waiting periods; exclusions; benefit and indemnity', 'Compare the insured event, benefit basis and evidence required under accident and health policies.', 'Distinguish fixed benefits from indemnity and identify common coverage limitations.'),
('IC11-C05-T04', 'forcible entry; money in transit; baggage; employee dishonesty; discovery; limits; security protections', 'Classify the property and cause of loss before selecting burglary, money, baggage or fidelity cover.', 'Distinguish theft-related policies by insured interest, event and responsible person.'),
('IC11-C05-T05', 'aviation hull and liability; rural exposures; crop and livestock; micro-insurance; accessibility; affordability', 'Compare specialist technical risk with inclusive products designed for underserved customers.', 'Explain the broad purpose of aviation, rural and micro-insurance and their differing design needs.'),

('IC11-C06-T01', 'construction works; erection; storage; testing; commissioning; third-party liability; project value; policy period', 'Build a project timeline and mark when each cover attaches, changes and expires.', 'Compare contractors-all-risks and erection-all-risks policies and their testing exposure.'),
('IC11-C06-T02', 'machinery breakdown; boiler explosion; pressure plant; electrical damage; electronic equipment; restoration', 'Identify the equipment, internal failure mechanism, external peril and resulting financial consequence.', 'Select the engineering policy that corresponds to machinery, pressure plant or electronic equipment.'),
('IC11-C06-T03', 'industrial all risks; broad property cover; exclusions; project delay; advance loss of profits; critical path', 'Coordinate the material-damage trigger with the financial effect of delayed commercial operation.', 'Explain how industrial-all-risks and advance-loss-of-profits protection work together.'),
('IC11-C06-T04', 'oil and gas; energy; offshore operations; satellite; accumulation; technical surveys; specialist wording; market capacity', 'Break a complex risk into physical assets, operations, liabilities, interruption and catastrophe accumulation.', 'Explain why specialised risks need technical underwriting, tailored wording and shared capacity.'),

('IC11-C07-T01', 'underwriting appetite; authority; guidelines; selection; portfolio balance; accumulation; profitability', 'Connect each individual decision to its effect on the insurer''s overall portfolio.', 'Explain how underwriting policy controls risk selection and protects portfolio quality.'),
('IC11-C07-T02', 'proposal information; inspections; classification; physical hazard; moral hazard; morale hazard; exposure measurement', 'Test completeness, reliability and materiality of every item of risk information.', 'Distinguish hazard types and explain how they affect acceptance, terms and premium.'),
('IC11-C07-T03', 'accept; decline; postpone; load premium; deductible; warranty; exclusion; documentation; renewal review', 'Record the reason, authority and evidence for every underwriting decision and policy term.', 'Compare underwriting options and explain why renewal requires fresh exposure review.'),
('IC11-C07-T04', 'co-insurance; lead insurer; following insurers; facultative reinsurance; treaty reinsurance; retention; capacity', 'Follow the contractual relationships and distinguish who contracts with the insured and who reimburses the insurer.', 'Distinguish co-insurance from reinsurance and facultative from treaty protection.'),
('IC11-C07-T05', 'expected claims cost; expenses; commission; catastrophe allowance; investment assumptions; profit; taxes; credibility', 'Build premium from the expected cost of risk and add each required loading transparently.', 'Explain the components of premium and why technically adequate rates matter.'),
('IC11-C07-T06', 'soft market; hard market; capacity; competition; rate adequacy; risk identification; control; financing; monitoring', 'Separate market pressure from the technical merits of the risk and document risk improvements.', 'Explain market-cycle effects and distinguish risk control from risk financing.'),

('IC11-C08-T01', 'prompt notice; emergency response; mitigation; evidence preservation; claim registration; communication', 'Use a first-notice checklist covering safety, mitigation, facts, documents and immediate support.', 'Explain why early notification and loss minimisation protect both insured and insurer.'),
('IC11-C08-T02', 'proximate cause; policy period; insured peril; exclusion; legal liability; investigation; fraud indicators', 'Build a fact chronology, then apply policy coverage and legal liability in separate stages.', 'Apply a structured coverage investigation without assuming that reported loss equals insured loss.'),
('IC11-C08-T03', 'surveyor; specialist; proof of loss; valuation; invoices; repair estimates; underinsurance; quantum', 'Create an evidence schedule linking each claimed amount to documents and policy valuation rules.', 'Explain the role of survey and how evidence supports a defensible loss assessment.'),
('IC11-C08-T04', 'case reserve; reserve revision; policy excess; depreciation; average; authority; payment; discharge', 'Reconcile assessed loss, policy adjustments, approvals and payment documentation.', 'Explain why reserves change and distinguish assessment from final settlement.'),
('IC11-C08-T05', 'coverage dispute; quantum dispute; arbitration; litigation; limitation; without-prejudice negotiation; evidence', 'Classify the dispute before choosing the contractual, judicial or negotiated resolution route.', 'Distinguish arbitration of quantum from disputes about policy liability.'),
('IC11-C08-T06', 'salvage; subrogation; contribution; third-party recovery; disposal; recovery costs; closure review', 'Protect physical salvage and legal rights from first notification through post-payment recovery.', 'Explain how salvage, subrogation and contribution reduce net claim cost.'),

('IC11-C09-T01', 'delayed claim cost; technical provisions; outstanding claims; IBNR; unexpired risk; fluctuation; solvency', 'Relate each reserve to the future obligation it is intended to finance.', 'Explain why technical reserves are liabilities and identify their principal types.'),
('IC11-C09-T02', 'case estimates; incurred but not reported claims; development; reopened claims; data triangles; uncertainty', 'Separate known reported claims from losses incurred but not yet visible in individual files.', 'Distinguish outstanding case reserves from IBNR and explain reserve development.'),
('IC11-C09-T03', 'written premium; earned premium; unearned premium; remaining coverage; unexpired-risk deficiency; matching', 'Use a policy timeline to separate the expired and unexpired portions of risk.', 'Explain why premium relating to future coverage cannot be treated wholly as current income.'),
('IC11-C09-T04', 'security; liquidity; yield; diversification; admissible assets; matching; concentration; regulatory limits', 'Evaluate an investment by its ability to support the timing and uncertainty of claim payments.', 'Explain the balance between safety, liquidity and return in insurer investment strategy.'),
('IC11-C09-T05', 'underwriting account; profit and loss; balance sheet; cash flow; claims ratio; combined ratio; solvency; management returns', 'Connect operational insurance data to financial statements and management indicators.', 'Interpret the principal reports and ratios used to monitor general insurance performance.');

DO $validate$
DECLARE
    v_subject_id bigint;
BEGIN
    SELECT subject_record.id INTO v_subject_id
    FROM public.subjects AS subject_record
    WHERE pg_catalog.upper(subject_record.code) = 'IC11'
      AND subject_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The active IC11 subject was not found.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.subject_topics AS topic_record
        JOIN ic11_remaining_content_seed AS seed
          ON seed.topic_code = pg_catalog.upper(topic_record.code)
        WHERE topic_record.subject_id = v_subject_id
          AND topic_record.is_active = true
    ) <> 39 THEN
        RAISE EXCEPTION 'All 39 active IC11 Chapter 2-9 topics are required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.learning_resource_types AS resource_type
        WHERE pg_catalog.upper(resource_type.code) = 'NOTE' AND resource_type.is_active = true
    ) OR NOT EXISTS (
        SELECT 1 FROM public.learning_resource_types AS resource_type
        WHERE pg_catalog.upper(resource_type.code) = 'REVISION_NOTE' AND resource_type.is_active = true
    ) THEN
        RAISE EXCEPTION 'The active NOTE and REVISION_NOTE resource types are required.';
    END IF;
END;
$validate$;

INSERT INTO public.learning_resources (
    subject_id, module_id, chapter_id, topic_id, resource_type_id,
    code, title, short_description, content, external_url,
    attachment_path, author_name, version_no, estimated_read_minutes,
    display_order, is_exam_relevant, is_premium, is_active
)
SELECT
    topic_record.subject_id,
    topic_record.module_id,
    topic_record.chapter_id,
    topic_record.id,
    resource_type.id,
    'LR-' || seed.topic_code || '-' ||
      CASE WHEN resource_type.code = 'NOTE' THEN '001' ELSE '002' END,
    CASE WHEN resource_type.code = 'NOTE'
      THEN topic_record.title
      ELSE 'Quick Revision: ' || topic_record.title
    END,
    CASE WHEN resource_type.code = 'NOTE'
      THEN topic_record.description
      ELSE 'Concise examination revision and practical application cues for ' || topic_record.title || '.'
    END,
    CASE WHEN resource_type.code = 'NOTE' THEN
      topic_record.title || E'\n\nOverview\n\n' || topic_record.description ||
      E'\n\nLearning objective\n\n' || topic_record.learning_objective ||
      E'\n\nCore learning framework\n\nStudy the topic through these connected elements: ' || seed.learning_focus ||
      E'. Do not treat the elements as isolated definitions. Identify the insured interest or legal duty, the event or exposure, the policy or institutional response, the important limitations, and the evidence required to support a decision.\n\nStudy method\n\n' || seed.study_method ||
      E' Consider a simple personal risk and a larger commercial risk, and test how the outcome changes when facts, limits or documents change.\n\nPractical relevance\n\n' || topic_record.practical_relevance ||
      E' A sound practitioner explains the reason for the decision, applies the complete wording or process, records material facts, and escalates technical or legal uncertainty.\n\nCurrent-practice note\n\nNumerical limits, prescribed forms and regulatory procedures may change. Use the course framework for examination preparation and verify time-sensitive requirements against current official sources before operational use.'
    ELSE
      'Quick Revision: ' || topic_record.title || E'\n\nKey scope\n\n' || topic_record.description ||
      E'\n\nRemember\n\n- Purpose: ' || topic_record.learning_objective ||
      E'\n- Core elements: ' || seed.learning_focus ||
      E'.\n- Application: ' || topic_record.practical_relevance ||
      E'\n- Method: ' || seed.study_method ||
      E'\n\nExam focus\n\n' || seed.exam_focus ||
      E' Compare related concepts, state the reason for each control or policy feature, and apply the framework to a short fact situation.\n\nMemory method\n\nIdentify the interest or duty; identify the exposure; identify the response; test limitations; retain evidence.\n\nAccuracy reminder\n\nVerify changeable legal limits, rates, forms and procedures against current official publications.'
    END,
    NULL,
    NULL,
    'InsureGPTE Editorial Team',
    1,
    CASE WHEN resource_type.code = 'NOTE' THEN 18 ELSE 6 END,
    CASE WHEN resource_type.code = 'NOTE' THEN 1 ELSE 2 END,
    true,
    false,
    true
FROM ic11_remaining_content_seed AS seed
JOIN public.subject_topics AS topic_record
  ON pg_catalog.upper(topic_record.code) = seed.topic_code
JOIN public.subjects AS subject_record
  ON subject_record.id = topic_record.subject_id
 AND pg_catalog.upper(subject_record.code) = 'IC11'
CROSS JOIN public.learning_resource_types AS resource_type
WHERE pg_catalog.upper(resource_type.code) IN ('NOTE', 'REVISION_NOTE')
  AND resource_type.is_active = true
  AND NOT EXISTS (
      SELECT 1 FROM public.learning_resources AS existing
      WHERE pg_catalog.upper(existing.code) =
        'LR-' || seed.topic_code || '-' ||
        CASE WHEN resource_type.code = 'NOTE' THEN '001' ELSE '002' END
  );

UPDATE public.learning_resources AS resource_record
SET title = generated.title,
    short_description = generated.short_description,
    content = generated.content,
    resource_type_id = generated.resource_type_id,
    external_url = NULL,
    attachment_path = NULL,
    author_name = 'InsureGPTE Editorial Team',
    version_no = 1,
    estimated_read_minutes = generated.estimated_read_minutes,
    display_order = generated.display_order,
    is_exam_relevant = true,
    is_premium = false,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM (
    SELECT
      'LR-' || seed.topic_code || '-' || CASE WHEN resource_type.code = 'NOTE' THEN '001' ELSE '002' END AS code,
      CASE WHEN resource_type.code = 'NOTE' THEN topic_record.title ELSE 'Quick Revision: ' || topic_record.title END AS title,
      CASE WHEN resource_type.code = 'NOTE' THEN topic_record.description ELSE 'Concise examination revision and practical application cues for ' || topic_record.title || '.' END AS short_description,
      CASE WHEN resource_type.code = 'NOTE' THEN
        topic_record.title || E'\n\nOverview\n\n' || topic_record.description || E'\n\nLearning objective\n\n' || topic_record.learning_objective || E'\n\nCore learning framework\n\nStudy the topic through these connected elements: ' || seed.learning_focus || E'. Do not treat the elements as isolated definitions. Identify the insured interest or legal duty, the event or exposure, the policy or institutional response, the important limitations, and the evidence required to support a decision.\n\nStudy method\n\n' || seed.study_method || E' Consider a simple personal risk and a larger commercial risk, and test how the outcome changes when facts, limits or documents change.\n\nPractical relevance\n\n' || topic_record.practical_relevance || E' A sound practitioner explains the reason for the decision, applies the complete wording or process, records material facts, and escalates technical or legal uncertainty.\n\nCurrent-practice note\n\nNumerical limits, prescribed forms and regulatory procedures may change. Use the course framework for examination preparation and verify time-sensitive requirements against current official sources before operational use.'
      ELSE
        'Quick Revision: ' || topic_record.title || E'\n\nKey scope\n\n' || topic_record.description || E'\n\nRemember\n\n- Purpose: ' || topic_record.learning_objective || E'\n- Core elements: ' || seed.learning_focus || E'.\n- Application: ' || topic_record.practical_relevance || E'\n- Method: ' || seed.study_method || E'\n\nExam focus\n\n' || seed.exam_focus || E' Compare related concepts, state the reason for each control or policy feature, and apply the framework to a short fact situation.\n\nMemory method\n\nIdentify the interest or duty; identify the exposure; identify the response; test limitations; retain evidence.\n\nAccuracy reminder\n\nVerify changeable legal limits, rates, forms and procedures against current official publications.'
      END AS content,
      resource_type.id AS resource_type_id,
      CASE WHEN resource_type.code = 'NOTE' THEN 18 ELSE 6 END AS estimated_read_minutes,
      CASE WHEN resource_type.code = 'NOTE' THEN 1 ELSE 2 END AS display_order
    FROM ic11_remaining_content_seed AS seed
    JOIN public.subject_topics AS topic_record
      ON pg_catalog.upper(topic_record.code) = seed.topic_code
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND pg_catalog.upper(subject_record.code) = 'IC11'
    CROSS JOIN public.learning_resource_types AS resource_type
    WHERE pg_catalog.upper(resource_type.code) IN ('NOTE', 'REVISION_NOTE')
) AS generated
WHERE pg_catalog.upper(resource_record.code) = generated.code;

INSERT INTO public.flashcards (
    subject_id, module_id, chapter_id, topic_id, code, question, answer,
    explanation, display_order, difficulty_level, is_exam_relevant, is_active
)
SELECT
    topic_record.subject_id,
    topic_record.module_id,
    topic_record.chapter_id,
    topic_record.id,
    'FC-' || seed.topic_code || '-' || pg_catalog.lpad(card.card_number::text, 3, '0'),
    card.question,
    card.answer,
    card.explanation,
    card.card_number,
    CASE WHEN card.card_number = 1 THEN 'foundation' ELSE topic_record.difficulty_level END,
    true,
    true
FROM ic11_remaining_content_seed AS seed
JOIN public.subject_topics AS topic_record
  ON pg_catalog.upper(topic_record.code) = seed.topic_code
JOIN public.subjects AS subject_record
  ON subject_record.id = topic_record.subject_id
 AND pg_catalog.upper(subject_record.code) = 'IC11'
CROSS JOIN LATERAL (
    VALUES
      (1, 'What is the central scope of ' || topic_record.title || '?', topic_record.description,
          'A complete answer identifies the subject, its purpose and the connected elements: ' || seed.learning_focus || '.'),
      (2, 'What should a learner be able to do after studying ' || topic_record.title || '?', topic_record.learning_objective,
          'Use this objective to structure comparison and application questions. ' || seed.study_method),
      (3, 'Why is ' || topic_record.title || ' practically relevant?', topic_record.practical_relevance,
          seed.exam_focus || ' Verify any time-sensitive rule against a current official source.')
) AS card(card_number, question, answer, explanation)
WHERE NOT EXISTS (
    SELECT 1 FROM public.flashcards AS existing
    WHERE pg_catalog.upper(existing.code) =
      'FC-' || seed.topic_code || '-' || pg_catalog.lpad(card.card_number::text, 3, '0')
);

UPDATE public.flashcards AS flashcard_record
SET question = generated.question,
    answer = generated.answer,
    explanation = generated.explanation,
    display_order = generated.card_number,
    difficulty_level = generated.difficulty_level,
    is_exam_relevant = true,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM (
    SELECT
      'FC-' || seed.topic_code || '-' || pg_catalog.lpad(card.card_number::text, 3, '0') AS code,
      card.question,
      card.answer,
      card.explanation,
      card.card_number,
      CASE WHEN card.card_number = 1 THEN 'foundation' ELSE topic_record.difficulty_level END AS difficulty_level
    FROM ic11_remaining_content_seed AS seed
    JOIN public.subject_topics AS topic_record
      ON pg_catalog.upper(topic_record.code) = seed.topic_code
    JOIN public.subjects AS subject_record
      ON subject_record.id = topic_record.subject_id
     AND pg_catalog.upper(subject_record.code) = 'IC11'
    CROSS JOIN LATERAL (
      VALUES
        (1, 'What is the central scope of ' || topic_record.title || '?', topic_record.description,
            'A complete answer identifies the subject, its purpose and the connected elements: ' || seed.learning_focus || '.'),
        (2, 'What should a learner be able to do after studying ' || topic_record.title || '?', topic_record.learning_objective,
            'Use this objective to structure comparison and application questions. ' || seed.study_method),
        (3, 'Why is ' || topic_record.title || ' practically relevant?', topic_record.practical_relevance,
            seed.exam_focus || ' Verify any time-sensitive rule against a current official source.')
    ) AS card(card_number, question, answer, explanation)
) AS generated
WHERE pg_catalog.upper(flashcard_record.code) = generated.code;

DO $verify$
DECLARE
    v_subject_id bigint;
BEGIN
    SELECT subject_record.id INTO v_subject_id
    FROM public.subjects AS subject_record
    WHERE pg_catalog.upper(subject_record.code) = 'IC11';

    IF (
        SELECT pg_catalog.count(*) FROM public.learning_resources AS resource_record
        JOIN public.subject_topics AS topic_record ON topic_record.id = resource_record.topic_id
        WHERE topic_record.subject_id = v_subject_id
          AND pg_catalog.upper(topic_record.code) BETWEEN 'IC11-C02-T01' AND 'IC11-C09-T05'
          AND resource_record.is_active = true
    ) <> 78 THEN
        RAISE EXCEPTION 'Expected exactly 78 active IC11 Chapter 2-9 resources.';
    END IF;

    IF (
        SELECT pg_catalog.count(*) FROM public.flashcards AS flashcard_record
        JOIN public.subject_topics AS topic_record ON topic_record.id = flashcard_record.topic_id
        WHERE topic_record.subject_id = v_subject_id
          AND pg_catalog.upper(topic_record.code) BETWEEN 'IC11-C02-T01' AND 'IC11-C09-T05'
          AND flashcard_record.is_active = true
    ) <> 117 THEN
        RAISE EXCEPTION 'Expected exactly 117 active IC11 Chapter 2-9 flashcards.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.subject_topics AS topic_record
        JOIN ic11_remaining_content_seed AS seed ON seed.topic_code = pg_catalog.upper(topic_record.code)
        WHERE (
          SELECT pg_catalog.count(*) FROM public.learning_resources AS resource_record
          WHERE resource_record.topic_id = topic_record.id AND resource_record.is_active = true
        ) <> 2 OR (
          SELECT pg_catalog.count(*) FROM public.flashcards AS flashcard_record
          WHERE flashcard_record.topic_id = topic_record.id AND flashcard_record.is_active = true
        ) <> 3
    ) THEN
        RAISE EXCEPTION 'Every remaining IC11 topic must have two resources and three flashcards.';
    END IF;
END;
$verify$;

DROP TABLE IF EXISTS pg_temp.ic11_remaining_content_seed;

COMMIT;
