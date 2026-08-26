-- Complete the approved IC01 Risk Management pilot chapter in the test project.
-- Topic 1 is intentionally preserved exactly as accepted during runtime testing.
-- Topics 2-7 receive one learning note, one revision note, and three flashcards.
-- Stable content codes make this migration safe to run again without duplicates.
-- No learner, progress, entitlement, activity, or practice-attempt rows are changed.

BEGIN;

DO $validate$
DECLARE
    v_subject_id integer;
    v_module_id integer;
    v_chapter_id integer;
BEGIN
    SELECT subject_record.id, module_record.id, chapter_record.id
    INTO v_subject_id, v_module_id, v_chapter_id
    FROM public.subjects AS subject_record
    JOIN public.subject_modules AS module_record
      ON module_record.subject_id = subject_record.id
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.subject_id = subject_record.id
     AND chapter_record.module_id = module_record.id
    WHERE pg_catalog.upper(subject_record.code) = 'IC01'
      AND pg_catalog.upper(module_record.code) = 'IC01-M01'
      AND pg_catalog.upper(chapter_record.code) = 'IC01-C01'
      AND subject_record.is_active = true
      AND module_record.is_active = true
      AND chapter_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION
            'The active IC01 / IC01-M01 / IC01-C01 hierarchy was not found.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.subject_topics AS topic_record
        WHERE topic_record.subject_id = v_subject_id
          AND topic_record.module_id = v_module_id
          AND topic_record.chapter_id = v_chapter_id
          AND pg_catalog.upper(topic_record.code) IN (
              'IC01-C01-T01', 'IC01-C01-T02', 'IC01-C01-T03',
              'IC01-C01-T04', 'IC01-C01-T05', 'IC01-C01-T06',
              'IC01-C01-T07'
          )
          AND topic_record.is_active = true
    ) <> 7 THEN
        RAISE EXCEPTION
            'All seven active IC01 Risk Management topics must exist before loading content.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.learning_resource_types AS resource_type
        WHERE pg_catalog.upper(resource_type.code) = 'NOTE'
          AND resource_type.is_active = true
    ) OR NOT EXISTS (
        SELECT 1 FROM public.learning_resource_types AS resource_type
        WHERE pg_catalog.upper(resource_type.code) = 'REVISION_NOTE'
          AND resource_type.is_active = true
    ) THEN
        RAISE EXCEPTION
            'The active NOTE and REVISION_NOTE resource types are required.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.learning_resources AS resource_record
        WHERE pg_catalog.upper(resource_record.code) IN (
            'LR-IC01-C01-T01-001', 'LR-IC01-C01-T01-002'
        )
          AND resource_record.topic_id = (
              SELECT topic_record.id
              FROM public.subject_topics AS topic_record
              WHERE topic_record.subject_id = v_subject_id
                AND pg_catalog.upper(topic_record.code) = 'IC01-C01-T01'
          )
    ) <> 2 OR NOT EXISTS (
        SELECT 1
        FROM public.flashcards AS flashcard_record
        WHERE pg_catalog.upper(flashcard_record.code) = 'FC-IC01-C01-T01-001'
          AND flashcard_record.topic_id = (
              SELECT topic_record.id
              FROM public.subject_topics AS topic_record
              WHERE topic_record.subject_id = v_subject_id
                AND pg_catalog.upper(topic_record.code) = 'IC01-C01-T01'
          )
    ) THEN
        RAISE EXCEPTION
            'The approved Topic 1 pilot content is incomplete; restore it before proceeding.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.learning_resources AS resource_record
        JOIN public.subject_topics AS topic_record
          ON topic_record.id = resource_record.topic_id
        WHERE pg_catalog.upper(resource_record.code) BETWEEN
              'LR-IC01-C01-T02-001' AND 'LR-IC01-C01-T07-002'
          AND (
              resource_record.subject_id <> v_subject_id
              OR topic_record.chapter_id <> v_chapter_id
              OR pg_catalog.upper(resource_record.code) NOT LIKE
                 'LR-' || pg_catalog.upper(topic_record.code) || '-%'
          )
    ) OR EXISTS (
        SELECT 1
        FROM public.flashcards AS flashcard_record
        JOIN public.subject_topics AS topic_record
          ON topic_record.id = flashcard_record.topic_id
        WHERE pg_catalog.upper(flashcard_record.code) BETWEEN
              'FC-IC01-C01-T02-001' AND 'FC-IC01-C01-T07-003'
          AND (
              flashcard_record.subject_id <> v_subject_id
              OR topic_record.chapter_id <> v_chapter_id
              OR pg_catalog.upper(flashcard_record.code) NOT LIKE
                 'FC-' || pg_catalog.upper(topic_record.code) || '-%'
          )
    ) THEN
        RAISE EXCEPTION
            'A planned IC01 content code is already assigned outside its intended topic.';
    END IF;
END;
$validate$;

DROP TABLE IF EXISTS pg_temp.ic01_resource_seed;

CREATE TEMPORARY TABLE ic01_resource_seed (
    topic_code text NOT NULL,
    resource_type_code text NOT NULL,
    code text PRIMARY KEY,
    title text NOT NULL,
    short_description text NOT NULL,
    content text NOT NULL,
    estimated_read_minutes integer NOT NULL,
    display_order integer NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO ic01_resource_seed VALUES
('IC01-C01-T02', 'NOTE', 'LR-IC01-C01-T02-001',
 'Classification of Risks',
 'A structured explanation of the principal classifications of risk and their insurance significance.',
 $content$
Risk can be classified in several ways. Each classification highlights a different feature and helps an insurance professional decide how the exposure should be managed.

Pure and speculative risk

Pure risk has only two broad outcomes: loss or no loss. Fire, accident, illness and premature death are common examples. Pure risks are the principal concern of insurance because insurance is designed to protect against adverse financial consequences, not to guarantee gains.

Speculative risk offers the possibility of loss, no change or gain. A business investment, a change in commodity prices or the purchase of shares may produce profit as well as loss. Speculative risks are generally not insured in the ordinary market because the possibility of gain is deliberately accepted.

Fundamental and particular risk

Fundamental risk affects large sections of society or the economy. Earthquakes, widespread floods, war, unemployment and severe inflation may affect many people at the same time. Government participation or special insurance arrangements may be necessary because the potential loss is very large and highly correlated.

Particular risk arises from an individual event and mainly affects one person, family or organisation. A house fire, theft from a shop or a motor accident is a particular risk and is commonly handled through insurance.

Static and dynamic risk

Static risks arise even when the economy is broadly unchanged. Dishonesty, fire and natural causes are examples. Dynamic risks result from changes in technology, consumer preferences, regulation, competition or the economy. Dynamic change can create losses but may also create opportunities.

Financial and non-financial risk

Financial risk can be measured in money, such as repair cost, lost income or liability compensation. Non-financial risk may involve discomfort, disappointment or loss of reputation and can be difficult to measure directly. Insurance normally requires a loss capable of financial assessment.

Insurable and non-insurable risk

An insurable risk ordinarily involves an uncertain and fortuitous event, a measurable financial loss, a lawful interest, and an exposure that an insurer can evaluate and pool. A risk may be non-insurable where loss is certain, deliberately caused, unlawful, impossible to measure, or so widespread that normal pooling cannot operate.

The classifications overlap. For example, a factory fire can be a pure, particular, static, financial and insurable risk. Classification is therefore an analytical tool rather than a set of mutually exclusive boxes.
$content$, 30, 1),
('IC01-C01-T02', 'REVISION_NOTE', 'LR-IC01-C01-T02-002',
 'Quick Revision: Classification of Risks',
 'Concise comparisons and examination cues for the principal classifications of risk.',
 $content$
Quick Revision Points

1. Pure risk: loss or no loss. It is the main field of insurance.
2. Speculative risk: loss, no change or gain. Ordinary insurance does not protect an expected trading profit.
3. Fundamental risk: affects a large population or the economy and may require state or market-wide solutions.
4. Particular risk: mainly affects an identifiable individual or organisation and is commonly insurable.
5. Static risk: exists without major economic change, for example fire or dishonesty.
6. Dynamic risk: arises from economic, technological, social or regulatory change.
7. Financial risk: the consequence can be expressed in money.
8. Non-financial risk: the consequence is difficult to measure directly in money.
9. Insurable risk must be fortuitous, lawful, measurable and capable of assessment and pooling.
10. One exposure may belong to several classifications at the same time.

Exam Focus

- Distinguish pure risk from speculative risk.
- Compare fundamental and particular risks.
- Explain why measurable financial loss matters to insurance.
- Apply more than one classification to the same example.

Memory Lines

Pure = Loss or No Loss
Speculative = Loss, No Change or Gain
Particular = Individual impact; Fundamental = Widespread impact
$content$, 6, 2),

('IC01-C01-T03', 'NOTE', 'LR-IC01-C01-T03-001',
 'Perils, Hazards and Risk Factors',
 'How perils cause loss and how physical, moral and morale hazards influence loss probability or severity.',
 $content$
Risk, peril and hazard describe different parts of a loss exposure.

Risk is the uncertainty concerning an adverse outcome. A peril is the immediate cause of a loss. Fire, flood, collision, theft and lightning are examples of perils. A hazard is a condition that increases either the probability that a peril will operate or the severity of the resulting loss.

Physical hazard

A physical hazard is a tangible feature of the property, activity or environment. Defective wiring increases the chance of fire; slippery flooring increases the chance of a fall; combustible stock can increase the severity of a fire. Physical hazards can often be observed during proposal review, inspection or engineering assessment and may be corrected through risk-improvement measures.

Moral hazard

Moral hazard arises from dishonesty, fraudulent intention or deliberate conduct. Examples include deliberately causing a loss, concealing important facts, inflating a claim or arranging excessive insurance with an improper motive. Underwriting, disclosure requirements, investigation and policy conditions help insurers control moral hazard.

Morale hazard

Morale hazard is carelessness or indifference caused by the knowledge that insurance exists. The insured may not intend to cause a loss but may exercise less care, leave property unsecured or neglect maintenance because the financial consequences appear transferable to an insurer. Deductibles, warranties and sound risk-management practices encourage continued responsibility.

Legal and environmental factors

Some texts also refer to legal hazard, where changes in law, court awards or the legal environment increase the frequency or cost of claims. Location, weather, surrounding occupancy and infrastructure may similarly influence an exposure.

The same event may involve several elements. In a warehouse fire, fire is the peril; defective wiring may be the physical hazard; deliberate ignition may indicate moral hazard; and poor housekeeping may reflect morale hazard.

Insurance professionals must identify the peril covered by the policy and the hazards surrounding the exposure. A hazard is not normally the loss itself; it modifies the chance or size of loss caused by a peril.
$content$, 30, 1),
('IC01-C01-T03', 'REVISION_NOTE', 'LR-IC01-C01-T03-002',
 'Quick Revision: Perils and Hazards',
 'Exam-oriented distinctions among risk, peril, physical hazard, moral hazard and morale hazard.',
 $content$
Quick Revision Points

1. Risk is uncertainty about an adverse outcome.
2. Peril is the immediate cause of loss, such as fire, flood, theft or collision.
3. Hazard is a condition that increases the frequency or severity of loss.
4. Physical hazard is a tangible condition, such as faulty wiring or unsafe machinery.
5. Moral hazard involves dishonesty or deliberate misconduct.
6. Morale hazard involves carelessness or indifference without a deliberate intention to cause loss.
7. A deductible can reduce morale hazard by keeping part of the loss with the insured.
8. Inspection and risk improvement primarily address physical hazards.
9. Proposal scrutiny and claims investigation help detect moral hazard.
10. The peril causes the loss; the hazard makes the loss more likely or more severe.

Example

Warehouse fire:
- Risk: uncertainty of property loss.
- Peril: fire.
- Physical hazard: combustible material near faulty wiring.
- Moral hazard: deliberate ignition for an improper claim.
- Morale hazard: careless storage because the property is insured.

Memory Line

Peril causes; Hazard influences.
$content$, 6, 2),

('IC01-C01-T04', 'NOTE', 'LR-IC01-C01-T04-001',
 'Direct and Consequential Losses',
 'The distinction between immediate physical loss and the secondary financial consequences that follow it.',
 $content$
A single event can cause both direct and consequential loss. Correctly identifying both is essential because one policy may not automatically cover every financial consequence.

Direct loss

Direct loss, also called actual or primary loss, is the immediate damage caused by an insured peril. If fire damages a factory building and machinery, the repair or replacement cost is the direct property loss. If a collision damages a vehicle, the physical damage is direct loss.

Consequential loss

Consequential loss, also called indirect or secondary loss, arises because the direct damage interrupts normal activity or produces further financial effects. After the factory fire, the business may lose gross profit, continue to pay fixed expenses, incur extra costs to operate temporarily elsewhere, or lose rent. These consequences follow the physical damage but are not themselves the damaged property.

The distinction is important in personal exposures as well. An accident may cause direct medical expenses and consequential loss of earnings. Damage to rented premises may cause direct repair costs and consequential loss of rental income.

Time element

Consequential loss frequently develops over time. Its amount depends on the duration of interruption, the resilience of the organisation, alternative facilities, supply chains and the speed of repair. For this reason, business-interruption insurance commonly uses an indemnity period and requires careful assessment of anticipated income and continuing expenses.

Coverage must be coordinated

A property policy usually addresses insured physical damage according to its terms. Consequential financial loss may require separate business-interruption, loss-of-profit, rent or other specialised coverage. The consequential policy commonly depends on the occurrence of insured damage, so gaps between policies can leave the insured exposed.

Risk-management implications

An exposure analysis should look beyond the value of the physical asset. It should consider dependency on key premises, machinery, utilities, suppliers, customers, data and skilled people. Continuity planning, backups and alternative arrangements can shorten interruption and reduce consequential loss.

Direct and consequential loss are connected but distinct. The first is the immediate result of the event; the second is the financial chain reaction that follows.
$content$, 25, 1),
('IC01-C01-T04', 'REVISION_NOTE', 'LR-IC01-C01-T04-002',
 'Quick Revision: Direct and Consequential Losses',
 'Fast comparison of primary property damage and the resulting time-dependent financial losses.',
 $content$
Quick Revision Points

1. Direct loss is the immediate physical or primary loss caused by a peril.
2. Consequential loss is the secondary financial effect that follows direct loss.
3. Fire-damaged machinery is direct loss; lost gross profit during shutdown is consequential loss.
4. Consequential loss often depends on the length of interruption.
5. Continuing fixed expenses and reasonable additional operating costs may form part of an interruption exposure.
6. A property policy does not automatically mean that every consequential loss is covered.
7. Business-interruption cover must be coordinated with the underlying material-damage cover.
8. The indemnity period should reflect a realistic restoration period.
9. Supplier, customer, utility and machinery dependencies can create significant indirect exposure.
10. Business-continuity measures can reduce the duration and size of consequential loss.

Exam Focus

- Identify the direct and indirect parts of a loss scenario.
- Explain why separate or coordinated coverage may be required.
- Relate the indemnity period to the duration of financial interruption.

Memory Line

Direct = Immediate Damage; Consequential = Financial Effect That Follows
$content$, 6, 2),

('IC01-C01-T05', 'NOTE', 'LR-IC01-C01-T05-001',
 'The Risk Management Process',
 'A practical sequence for establishing context, identifying, analysing, evaluating, treating and monitoring risk.',
 $content$
Risk management is a continuous and systematic process for understanding uncertainty and choosing suitable responses. It is wider than buying insurance: insurance is one possible treatment within the process.

1. Establish objectives and context

The organisation first defines what it is trying to protect or achieve, its legal and operational environment, the scope of the review and its willingness and capacity to retain risk. Clear objectives make later decisions meaningful.

2. Identify risks

Risk identification asks what can happen, why it can happen and what may be affected. Information may come from inspections, interviews, process maps, checklists, incident records, contracts, financial statements and scenario analysis. Both obvious and emerging exposures should be considered.

3. Analyse and measure risks

Analysis considers likelihood and consequence. Past experience, exposure data, engineering judgement and financial modelling may be used. Frequency describes how often a loss may occur; severity describes how large it may be. Existing controls must be considered when estimating the residual risk.

4. Evaluate and prioritise risks

Analysed risks are compared with agreed criteria and risk appetite. High-severity or unacceptable exposures receive priority even where frequency is low. The purpose is to decide which risks require treatment and in what order.

5. Select and implement treatment

Treatment may avoid the activity, prevent or reduce loss, retain the risk, transfer it contractually, finance it internally or insure it. A treatment plan identifies responsibilities, resources, timing and expected results. Several techniques may be combined.

6. Monitor and review

Risks, controls, values and business conditions change. Performance indicators, incidents, near misses, claims and control testing should therefore be reviewed. The risk register and insurance programme must be updated when circumstances change.

Communication and documentation operate throughout every stage. Stakeholders need accurate information, and decisions should be recorded so that responsibility and reasoning are clear.

The process is cyclical. Monitoring creates new information, which may change the context, reveal new risks or require different treatment. Effective risk management therefore supports better decisions, resilience and efficient use of insurance.
$content$, 35, 1),
('IC01-C01-T05', 'REVISION_NOTE', 'LR-IC01-C01-T05-002',
 'Quick Revision: Risk Management Process',
 'The risk-management cycle, frequency and severity, prioritisation, treatment and continuing review.',
 $content$
Quick Revision Sequence

1. Establish objectives, scope and context.
2. Identify what can happen and what may be affected.
3. Analyse likelihood, consequence and existing controls.
4. Evaluate and prioritise against risk criteria and appetite.
5. Select and implement suitable treatment.
6. Monitor, review and improve.
7. Communicate and document throughout the process.

Core Measures

- Frequency: how often loss may occur.
- Severity: how large the loss may be.
- Inherent risk: exposure before considering controls.
- Residual risk: exposure remaining after controls.

Treatment Choices

- Avoid.
- Prevent or reduce.
- Retain and finance.
- Transfer by contract.
- Transfer through insurance.

Exam Focus

- Put the stages in logical order.
- Do not treat insurance purchase as the entire process.
- Distinguish analysis from evaluation: analysis estimates the risk; evaluation compares it with criteria.
- Recognise that monitoring may restart the cycle.

Memory Line

Context - Identify - Analyse - Evaluate - Treat - Monitor
$content$, 7, 2),

('IC01-C01-T06', 'NOTE', 'LR-IC01-C01-T06-001',
 'Risk Control Techniques',
 'Methods that avoid exposure or reduce the frequency and severity of loss before financing is considered.',
 $content$
Risk control changes the exposure itself. Its objective is to eliminate an unacceptable activity or reduce how often losses occur and how serious they become. Risk control should be distinguished from risk financing, which provides funds after loss.

Risk avoidance

Avoidance removes the exposure by not starting or by discontinuing the activity. A company may stop using a dangerous process or decline to enter a hazardous market. Avoidance can eliminate a particular risk, but it may also remove the related benefit or create another exposure. It is most suitable where the risk is unacceptable and cannot be adequately controlled.

Loss prevention

Prevention reduces loss frequency. Examples include staff training, preventive maintenance, access control, safe operating procedures, driver screening and routine inspections. Prevention aims to stop an event from occurring.

Loss reduction

Reduction limits severity when an event does occur. Fire detection and suppression, emergency response, protective equipment, salvage arrangements and disaster-recovery plans are examples. Some measures, such as good housekeeping, may influence both frequency and severity.

Segregation and separation

Segregation divides assets or operations so that one event cannot affect the entire value. Stock may be stored in separate fire compartments or locations. Separation places exposures far enough apart that the same event is less likely to damage all of them. The benefit depends on genuine independence: two buildings in the same flood zone may still share one catastrophe exposure.

Duplication

Duplication creates a standby copy or alternative capacity. Backup data, spare machinery, alternate suppliers and duplicate records help operations recover when the primary resource fails. Backups must be protected, current and tested; an untested copy at the same location may provide little protection.

Combination and cost-effectiveness

Organisations normally combine controls. The best choice considers legal duties, human safety, expected loss reduction, reliability and cost. Controls should not be selected only because insurance requires them; they should support sound operations and resilience.

Controls must be implemented, assigned to responsible persons and monitored. A written procedure has limited value unless people follow it and its effectiveness is tested.
$content$, 35, 1),
('IC01-C01-T06', 'REVISION_NOTE', 'LR-IC01-C01-T06-002',
 'Quick Revision: Risk Control Techniques',
 'Comparison of avoidance, prevention, reduction, segregation, separation and duplication.',
 $content$
Quick Revision Points

1. Risk control changes the exposure; risk financing pays for loss consequences.
2. Avoidance removes the activity or exposure.
3. Loss prevention reduces frequency.
4. Loss reduction reduces severity.
5. Segregation divides assets or operations into smaller units.
6. Separation places units far enough apart to reduce common-event damage.
7. Duplication provides backup property, data, suppliers or capacity.
8. A control may affect both frequency and severity.
9. Backups must be independent, current and tested.
10. Controls need ownership, implementation and monitoring.

Examples

- Driver training: prevention.
- Sprinkler system: reduction, and sometimes prevention of spread.
- Stock in independent locations: segregation or separation.
- Off-site tested data backup: duplication.
- Discontinuing a dangerous process: avoidance.

Exam Focus

- Match each technique to its main purpose.
- Distinguish prevention from reduction.
- Explain why geographical separation must address common catastrophe exposure.

Memory Line

Prevent Frequency; Reduce Severity; Duplicate for Recovery
$content$, 7, 2),

('IC01-C01-T07', 'NOTE', 'LR-IC01-C01-T07-001',
 'Risk Financing and Insurance',
 'How retention, self-insurance, contractual transfer and insurance provide funds for loss consequences.',
 $content$
Risk financing determines how the financial consequences of retained or transferred risks will be met. It operates alongside risk control: controls aim to change the likelihood or severity of loss, while financing ensures that money or resources are available when loss occurs.

Retention

Retention means that the individual or organisation bears some or all of the loss. Retention may be deliberate, after analysis, or unplanned because an exposure was overlooked, excluded or insufficiently insured. Small predictable losses may be efficiently retained as normal operating costs. Deductibles are a common form of partial retention.

Funded and unfunded retention

Under funded retention, money is deliberately accumulated or arranged in advance through reserves, a dedicated fund or a credit facility. Under unfunded retention, losses are paid from current income or general assets when they occur. The latter can create liquidity pressure if losses are larger or more frequent than expected.

Self-insurance

Self-insurance is a planned form of retention under which an organisation systematically finances its own losses, often using loss data, formal funding and administration. Merely failing to purchase insurance is not sound self-insurance. Large or catastrophic loss may still need conventional insurance or other protection.

Non-insurance transfer

Contracts can allocate responsibility to another party through indemnity clauses, hold-harmless agreements, leases, warranties or outsourcing arrangements. The transfer is only as reliable as the wording, legality and financial capacity of the other party. Contractual transfer may create legal responsibility but does not automatically provide cash unless it is backed by insurance or adequate resources.

Insurance transfer

Insurance transfers specified financial consequences to an insurer in exchange for premium, subject to the policy terms, conditions, limits, deductibles and exclusions. It is especially valuable for uncertain losses that could seriously affect financial stability. Insurance does not remove the underlying hazard and does not transfer every consequence.

Selecting a financing method

The decision considers frequency, severity, predictability, cash flow, risk appetite, legal requirements, cost of insurance, insurer capacity and the organisation's ability to administer retained claims. High-frequency low-severity losses may be retained; low-frequency high-severity losses are commonly transferred, though each case requires analysis.

A sound programme combines reasonable retention, effective control and suitable insurance. Deductibles and limits should reflect the insured's financial capacity, not merely the desire to reduce premium.
$content$, 35, 1),
('IC01-C01-T07', 'REVISION_NOTE', 'LR-IC01-C01-T07-002',
 'Quick Revision: Risk Financing and Insurance',
 'Retention, self-insurance, contractual transfer, insurance and the considerations governing their selection.',
 $content$
Quick Revision Points

1. Risk financing provides funds for the financial consequences of loss.
2. Retention means bearing some or all of the loss.
3. Deliberate retention follows analysis; unplanned retention arises from oversight, exclusions or inadequate cover.
4. Funded retention sets resources aside in advance.
5. Unfunded retention pays losses from current income or general assets.
6. Self-insurance is organised and planned retention, not simply absence of insurance.
7. A deductible is partial retention by the insured.
8. Non-insurance transfer uses contracts to allocate responsibility.
9. Insurance transfers specified financial consequences, subject to policy terms.
10. Insurance does not eliminate hazards or cover every consequence.

General Pattern

- Frequent, smaller and predictable losses may be retained.
- Severe, less frequent and financially disruptive losses are commonly transferred.
- Catastrophic exposure requires attention to insurer capacity, limits and continuity arrangements.

Exam Focus

- Distinguish risk control from risk financing.
- Distinguish planned self-insurance from uninsured exposure.
- Explain why contractual transfer depends on wording and counterparty strength.

Memory Line

Control Changes the Risk; Financing Pays the Loss
$content$, 7, 2);

INSERT INTO public.learning_resources (
    subject_id, module_id, chapter_id, topic_id, resource_type_id,
    code, title, short_description, content, external_url,
    attachment_path, author_name, version_no, estimated_read_minutes,
    display_order, is_exam_relevant, is_premium, is_active
)
SELECT
    subject_record.id,
    module_record.id,
    chapter_record.id,
    topic_record.id,
    resource_type.id,
    seed.code,
    seed.title,
    seed.short_description,
    seed.content,
    NULL,
    NULL,
    'InsureGPTE Editorial Team',
    1,
    seed.estimated_read_minutes,
    seed.display_order,
    true,
    false,
    true
FROM ic01_resource_seed AS seed
JOIN public.subjects AS subject_record
  ON pg_catalog.upper(subject_record.code) = 'IC01'
JOIN public.subject_modules AS module_record
  ON module_record.subject_id = subject_record.id
 AND pg_catalog.upper(module_record.code) = 'IC01-M01'
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.subject_id = subject_record.id
 AND chapter_record.module_id = module_record.id
 AND pg_catalog.upper(chapter_record.code) = 'IC01-C01'
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = subject_record.id
 AND topic_record.module_id = module_record.id
 AND topic_record.chapter_id = chapter_record.id
 AND pg_catalog.upper(topic_record.code) = seed.topic_code
JOIN public.learning_resource_types AS resource_type
  ON pg_catalog.upper(resource_type.code) = seed.resource_type_code
WHERE NOT EXISTS (
    SELECT 1
    FROM public.learning_resources AS existing
    WHERE pg_catalog.upper(existing.code) = seed.code
);

UPDATE public.learning_resources AS resource_record
SET resource_type_id = resource_type.id,
    title = seed.title,
    short_description = seed.short_description,
    content = seed.content,
    external_url = NULL,
    attachment_path = NULL,
    author_name = 'InsureGPTE Editorial Team',
    version_no = 1,
    estimated_read_minutes = seed.estimated_read_minutes,
    display_order = seed.display_order,
    is_exam_relevant = true,
    is_premium = false,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM ic01_resource_seed AS seed
JOIN public.learning_resource_types AS resource_type
  ON pg_catalog.upper(resource_type.code) = seed.resource_type_code
WHERE pg_catalog.upper(resource_record.code) = seed.code;

DROP TABLE IF EXISTS pg_temp.ic01_flashcard_seed;

CREATE TEMPORARY TABLE ic01_flashcard_seed (
    topic_code text NOT NULL,
    code text PRIMARY KEY,
    question text NOT NULL,
    answer text NOT NULL,
    explanation text NOT NULL,
    display_order integer NOT NULL,
    difficulty_level text NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO ic01_flashcard_seed VALUES
('IC01-C01-T02', 'FC-IC01-C01-T02-001', 'How does pure risk differ from speculative risk?',
 'Pure risk offers loss or no loss, whereas speculative risk may result in loss, no change or gain.',
 'Insurance ordinarily addresses pure risks because its purpose is protection against adverse financial consequences rather than assurance of trading gains.', 1, 'foundation'),
('IC01-C01-T02', 'FC-IC01-C01-T02-002', 'What is the difference between a fundamental risk and a particular risk?',
 'A fundamental risk affects a large section of society or the economy, while a particular risk mainly affects an identifiable individual or organisation.',
 'Widespread correlated losses may need government or special market arrangements; particular risks are more readily pooled through ordinary insurance.', 2, 'foundation'),
('IC01-C01-T02', 'FC-IC01-C01-T02-003', 'Why is financial measurement important to insurability?',
 'The insurer must be able to express the loss in money so that the exposure, premium and claim amount can be assessed.',
 'A non-financial effect may be important, but ordinary insurance responds through a measurable financial benefit or indemnity.', 3, 'foundation'),

('IC01-C01-T03', 'FC-IC01-C01-T03-001', 'What is the difference between a peril and a hazard?',
 'A peril is the immediate cause of loss; a hazard is a condition that increases the probability or severity of loss.',
 'Fire may be the peril, while defective wiring is a physical hazard that makes fire more likely.', 1, 'foundation'),
('IC01-C01-T03', 'FC-IC01-C01-T03-002', 'How do moral hazard and morale hazard differ?',
 'Moral hazard involves dishonesty or deliberate misconduct; morale hazard involves carelessness or indifference without deliberate intent to cause loss.',
 'Fraudulent ignition is moral hazard, while neglecting precautions because property is insured is morale hazard.', 2, 'foundation'),
('IC01-C01-T03', 'FC-IC01-C01-T03-003', 'Give two examples of physical hazard.',
 'Defective electrical wiring and combustible stock stored without adequate protection are physical hazards.',
 'They are tangible conditions that can increase the chance or severity of fire loss and may be identified during inspection.', 3, 'foundation'),

('IC01-C01-T04', 'FC-IC01-C01-T04-001', 'What is a direct loss?',
 'A direct loss is the immediate physical or primary loss caused by a peril, such as fire damage to machinery.',
 'It concerns the property or interest directly affected by the event.', 1, 'intermediate'),
('IC01-C01-T04', 'FC-IC01-C01-T04-002', 'What is a consequential loss?',
 'A consequential loss is a secondary financial loss that follows direct damage, such as lost gross profit during a shutdown.',
 'It develops because the damaged property can no longer support normal activity and often depends on interruption duration.', 2, 'intermediate'),
('IC01-C01-T04', 'FC-IC01-C01-T04-003', 'Why must property and business-interruption cover be coordinated?',
 'Physical-damage cover may not insure the resulting loss of income, and interruption cover commonly depends on insured material damage.',
 'Aligned perils, values, limits and indemnity periods reduce gaps between the direct and consequential-loss protections.', 3, 'intermediate'),

('IC01-C01-T05', 'FC-IC01-C01-T05-001', 'What are the main stages of the risk-management process?',
 'Establish context, identify risks, analyse them, evaluate and prioritise them, select and implement treatment, then monitor and review.',
 'Communication and documentation support every stage, and monitoring makes the process continuous.', 1, 'intermediate'),
('IC01-C01-T05', 'FC-IC01-C01-T05-002', 'How do frequency and severity differ?',
 'Frequency is how often a loss may occur; severity is how large the loss may be.',
 'Both dimensions are considered when analysing exposure and selecting control and financing methods.', 2, 'foundation'),
('IC01-C01-T05', 'FC-IC01-C01-T05-003', 'What is residual risk?',
 'Residual risk is the risk that remains after existing controls have been considered.',
 'It must be compared with risk criteria to decide whether further treatment, retention or transfer is required.', 3, 'intermediate'),

('IC01-C01-T06', 'FC-IC01-C01-T06-001', 'How does loss prevention differ from loss reduction?',
 'Loss prevention reduces the frequency of events; loss reduction limits their severity after they occur.',
 'Driver training is mainly prevention, while a sprinkler system mainly reduces fire severity and spread.', 1, 'intermediate'),
('IC01-C01-T06', 'FC-IC01-C01-T06-002', 'What is risk avoidance?',
 'Risk avoidance removes an exposure by not starting or by discontinuing the activity that creates it.',
 'It may eliminate a particular risk but can also eliminate the related benefit or create another exposure.', 2, 'foundation'),
('IC01-C01-T06', 'FC-IC01-C01-T06-003', 'Why must duplicated data or equipment be independent and tested?',
 'A backup exposed to the same event or one that cannot operate when needed does not provide effective recovery capacity.',
 'Off-site protection, currency and regular testing make duplication a reliable risk-control technique.', 3, 'intermediate'),

('IC01-C01-T07', 'FC-IC01-C01-T07-001', 'What is risk retention?',
 'Risk retention means that an individual or organisation bears some or all of the financial consequences of loss.',
 'Retention may be deliberate and funded, or unplanned because an exposure was overlooked, excluded or underinsured.', 1, 'intermediate'),
('IC01-C01-T07', 'FC-IC01-C01-T07-002', 'Why is simply having no insurance not necessarily self-insurance?',
 'Self-insurance is a planned and organised method of financing retained losses using analysis, funding and administration.',
 'Unexamined absence of insurance is merely uninsured or unplanned retention and may create serious liquidity risk.', 2, 'intermediate'),
('IC01-C01-T07', 'FC-IC01-C01-T07-003', 'How does risk control differ from risk financing?',
 'Risk control changes the likelihood or severity of loss, while risk financing provides funds for its financial consequences.',
 'A sound programme combines controls, reasonable retention and suitable insurance rather than relying on only one method.', 3, 'intermediate');

INSERT INTO public.flashcards (
    subject_id, module_id, chapter_id, topic_id, code, question, answer,
    explanation, display_order, difficulty_level, is_exam_relevant, is_active
)
SELECT
    subject_record.id,
    module_record.id,
    chapter_record.id,
    topic_record.id,
    seed.code,
    seed.question,
    seed.answer,
    seed.explanation,
    seed.display_order,
    seed.difficulty_level,
    true,
    true
FROM ic01_flashcard_seed AS seed
JOIN public.subjects AS subject_record
  ON pg_catalog.upper(subject_record.code) = 'IC01'
JOIN public.subject_modules AS module_record
  ON module_record.subject_id = subject_record.id
 AND pg_catalog.upper(module_record.code) = 'IC01-M01'
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.subject_id = subject_record.id
 AND chapter_record.module_id = module_record.id
 AND pg_catalog.upper(chapter_record.code) = 'IC01-C01'
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = subject_record.id
 AND topic_record.module_id = module_record.id
 AND topic_record.chapter_id = chapter_record.id
 AND pg_catalog.upper(topic_record.code) = seed.topic_code
WHERE NOT EXISTS (
    SELECT 1
    FROM public.flashcards AS existing
    WHERE pg_catalog.upper(existing.code) = seed.code
);

UPDATE public.flashcards AS flashcard_record
SET question = seed.question,
    answer = seed.answer,
    explanation = seed.explanation,
    display_order = seed.display_order,
    difficulty_level = seed.difficulty_level,
    is_exam_relevant = true,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM ic01_flashcard_seed AS seed
WHERE pg_catalog.upper(flashcard_record.code) = seed.code;

DO $verify$
DECLARE
    v_subject_id integer;
    v_chapter_id integer;
BEGIN
    SELECT subject_record.id, chapter_record.id
    INTO v_subject_id, v_chapter_id
    FROM public.subjects AS subject_record
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.subject_id = subject_record.id
    WHERE pg_catalog.upper(subject_record.code) = 'IC01'
      AND pg_catalog.upper(chapter_record.code) = 'IC01-C01';

    IF (
        SELECT pg_catalog.count(*)
        FROM public.learning_resources AS resource_record
        JOIN public.subject_topics AS topic_record
          ON topic_record.id = resource_record.topic_id
        WHERE resource_record.subject_id = v_subject_id
          AND topic_record.chapter_id = v_chapter_id
          AND resource_record.is_active = true
    ) <> 14 THEN
        RAISE EXCEPTION
            'Expected exactly 14 active IC01 Risk Management resources after migration.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.flashcards AS flashcard_record
        JOIN public.subject_topics AS topic_record
          ON topic_record.id = flashcard_record.topic_id
        WHERE flashcard_record.subject_id = v_subject_id
          AND topic_record.chapter_id = v_chapter_id
          AND flashcard_record.is_active = true
    ) <> 19 THEN
        RAISE EXCEPTION
            'Expected exactly 19 active IC01 Risk Management flashcards after migration.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subject_topics AS topic_record
        WHERE topic_record.subject_id = v_subject_id
          AND topic_record.chapter_id = v_chapter_id
          AND topic_record.is_active = true
          AND (
              SELECT pg_catalog.count(*)
              FROM public.learning_resources AS resource_record
              WHERE resource_record.topic_id = topic_record.id
                AND resource_record.is_active = true
          ) <> 2
    ) THEN
        RAISE EXCEPTION
            'Every active IC01 Risk Management topic must have two active resources.';
    END IF;
END;
$verify$;

DROP TABLE IF EXISTS pg_temp.ic01_flashcard_seed;
DROP TABLE IF EXISTS pg_temp.ic01_resource_seed;

COMMIT;
