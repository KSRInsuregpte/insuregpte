-- Seed the complete IC14 topic hierarchy with explicit addendum-controlled scope.
-- No learning content or learner records are changed by this migration.

BEGIN;

DROP TABLE IF EXISTS public.migration_ic14_topic_seed;

CREATE TABLE public.migration_ic14_topic_seed (
  module_code text NOT NULL,
  chapter_code text NOT NULL,
  topic_number integer NOT NULL,
  code text PRIMARY KEY,
  title text NOT NULL,
  focus text NOT NULL,
  estimated_study_minutes integer NOT NULL,
  difficulty_level text NOT NULL
);

ALTER TABLE public.migration_ic14_topic_seed ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.migration_ic14_topic_seed FROM anon, authenticated;

INSERT INTO public.migration_ic14_topic_seed VALUES
('IC14-M01','IC14-C01',1,'IC14-C01-T01','Development of Insurance Legislation in India','early legislation; life and general insurance development; comprehensive regulation',35,'foundation'),
('IC14-M01','IC14-C01',2,'IC14-C01-T02','Nationalisation of Life and General Insurance','LIC framework; general insurance nationalisation; GIC and public-sector structure',35,'foundation'),
('IC14-M01','IC14-C01',3,'IC14-C01-T03','Insurance Sector Reforms and Liberalisation','Malhotra Committee; private participation; regulatory reform; market opening',40,'intermediate'),
('IC14-M01','IC14-C01',4,'IC14-C01-T04','Foreign Investment and Ownership Controls','foreign-investment framework; ownership and control; 2023 III addendum examination value',35,'intermediate'),

('IC14-M01','IC14-C02',1,'IC14-C02-T01','IRDAI Purpose, Establishment and Composition','statutory establishment; regulatory mission; membership; institutional independence',35,'foundation'),
('IC14-M01','IC14-C02',2,'IC14-C02-T02','IRDAI Duties, Powers and Functions','policyholder protection; regulation; promotion; orderly growth; statutory powers',45,'intermediate'),
('IC14-M01','IC14-C02',3,'IC14-C02-T03','Insurance Councils and Advisory Institutions','Life and General Insurance Councils; committees; advisory and representative functions',35,'intermediate'),
('IC14-M01','IC14-C02',4,'IC14-C02-T04','Regulatory Supervision and Enforcement','returns; inspection; investigation; directions; corrective action; penalties',40,'intermediate'),

('IC14-M02','IC14-C03',1,'IC14-C03-T01','Registration of Insurers','eligibility; application; capital; business plan; registration; continuing conditions',45,'intermediate'),
('IC14-M02','IC14-C03',2,'IC14-C03-T02','Licensing and Appointment of Insurance Agents','eligibility; training; examination; appointment; conduct; termination',40,'intermediate'),
('IC14-M02','IC14-C03',3,'IC14-C03-T03','Insurance Brokers and Addendum Requirements','direct, reinsurance and composite brokers; functions; training hours; capital under III addendum',50,'advanced'),
('IC14-M02','IC14-C03',4,'IC14-C03-T04','Surveyors, Loss Assessors and Other Intermediaries','survey and assessment; TPAs; corporate agents; web aggregators; regulated service providers',45,'intermediate'),
('IC14-M02','IC14-C03',5,'IC14-C03-T05','Corporate Governance and Regulatory Fitness','board oversight; key management; fit-and-proper expectations; controls; compliance culture',40,'advanced'),

('IC14-M02','IC14-C04',1,'IC14-C04-T01','Product and Conduct-of-Business Regulation','product governance; filing or approval; policy terms; sales and servicing controls',45,'intermediate'),
('IC14-M02','IC14-C04',2,'IC14-C04-T02','Distribution Channels and Codes of Conduct','agents; brokers; corporate agents; digital channels; duties and prohibited practices',45,'intermediate'),
('IC14-M02','IC14-C04',3,'IC14-C04-T03','Advertising, Disclosure and Sales Practices','fair communication; benefit and risk disclosure; suitability; records; misleading promotion',40,'intermediate'),
('IC14-M02','IC14-C04',4,'IC14-C04-T04','Rural and Social-Sector Obligations','inclusion objectives; prescribed obligations; monitoring; underserved markets',35,'intermediate'),
('IC14-M02','IC14-C04',5,'IC14-C04-T05','AML, KYC and Market Integrity','customer identification; beneficial ownership; monitoring; reporting; fraud and sanctions controls',45,'advanced'),

('IC14-M03','IC14-C05',1,'IC14-C05-T01','Assignment of Insurance Policies','transfer of rights; legal effect; notice; restrictions; insurer records',40,'intermediate'),
('IC14-M03','IC14-C05',2,'IC14-C05-T02','Nomination and Beneficiary Rights','purpose of nomination; nominee; policy proceeds; succession considerations',40,'intermediate'),
('IC14-M03','IC14-C05',3,'IC14-C05-T03','Transfer, Alteration and Policy Servicing','policy changes; endorsements; servicing requests; records; communication',35,'intermediate'),
('IC14-M03','IC14-C05',4,'IC14-C05-T04','Free-Look Rights and Customer Choice','review period; cancellation; disclosure; refund adjustments; servicing evidence',35,'foundation'),

('IC14-M03','IC14-C06',1,'IC14-C06-T01','Proposal, Disclosure and Policy Issuance','proposal information; material facts; acceptance; policy delivery; discrepancy review',40,'intermediate'),
('IC14-M03','IC14-C06',2,'IC14-C06-T02','Protection of Policyholder Interests','fair treatment; information; servicing standards; communications; accountability',45,'intermediate'),
('IC14-M03','IC14-C06',3,'IC14-C06-T03','Claims Procedures and Settlement Standards','notification; documents; investigation; decision; payment; delay communication',45,'intermediate'),
('IC14-M03','IC14-C06',4,'IC14-C06-T04','Unfair Practices and Customer Remedies','mis-selling; unreasonable delay; deficiency; repudiation communication; remedial routes',40,'advanced'),

('IC14-M04','IC14-C07',1,'IC14-C07-T01','Internal Grievance Redressal','complaint registration; escalation; response; tracking; governance; regulatory reporting',35,'foundation'),
('IC14-M04','IC14-C07',2,'IC14-C07-T02','Consumer Commissions and Addendum Limits','three-tier consumer machinery; jurisdiction; appeal periods and deposits under III addendum',50,'advanced'),
('IC14-M04','IC14-C07',3,'IC14-C07-T03','Insurance Ombudsman and Addendum Threshold','eligible complaints; preconditions; procedure; awards; relief threshold under III addendum',45,'intermediate'),
('IC14-M04','IC14-C07',4,'IC14-C07-T04','Appeals, Courts and Alternative Dispute Resolution','appeal routes; arbitration; litigation; limitation; evidence; remedy selection',45,'advanced'),

('IC14-M05','IC14-C08',1,'IC14-C08-T01','Solvency Margin and Capital Adequacy','available and required solvency; risk absorption; intervention; policyholder security',45,'advanced'),
('IC14-M05','IC14-C08',2,'IC14-C08-T02','Investment Regulation of Insurers','admissible assets; exposure limits; security; liquidity; diversification; governance',45,'advanced'),
('IC14-M05','IC14-C08',3,'IC14-C08-T03','Technical Reserves and Actuarial Control','premium and claim liabilities; valuation; adequacy; actuarial oversight',45,'advanced'),
('IC14-M05','IC14-C08',4,'IC14-C08-T04','Financial Reporting and Regulatory Returns','accounts; audit; disclosures; regulatory returns; management and supervisory information',40,'advanced'),

('IC14-M05','IC14-C09',1,'IC14-C09-T01','IAIS Principles and Global Supervision','IAIS role; Insurance Core Principles; supervisory cooperation; proportionality',40,'advanced'),
('IC14-M05','IC14-C09',2,'IC14-C09-T02','International Regulatory Models','institutional, functional and integrated supervision; group-wide and cross-border oversight',40,'advanced'),
('IC14-M05','IC14-C09',3,'IC14-C09-T03','Emerging Trends in Insurance Regulation','technology; cyber risk; climate risk; conduct; resilience; data; evolving supervision',40,'advanced');

DO $validate$
DECLARE v_subject_id bigint;
BEGIN
  SELECT id INTO v_subject_id FROM public.subjects
  WHERE pg_catalog.upper(code) = 'IC14' AND is_active = true;
  IF v_subject_id IS NULL THEN RAISE EXCEPTION 'The active IC14 subject was not found.'; END IF;
  IF (SELECT pg_catalog.count(*) FROM public.subject_modules WHERE subject_id=v_subject_id AND is_active=true) <> 5
    THEN RAISE EXCEPTION 'Exactly five active IC14 modules are required.'; END IF;
  IF (SELECT pg_catalog.count(*) FROM public.subject_chapters WHERE subject_id=v_subject_id AND is_active=true) <> 9
    THEN RAISE EXCEPTION 'Exactly nine active IC14 chapters are required.'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.migration_ic14_topic_seed seed
    LEFT JOIN public.subject_modules module_record ON module_record.subject_id=v_subject_id AND pg_catalog.upper(module_record.code)=seed.module_code
    LEFT JOIN public.subject_chapters chapter_record ON chapter_record.subject_id=v_subject_id AND chapter_record.module_id=module_record.id AND pg_catalog.upper(chapter_record.code)=seed.chapter_code
    WHERE module_record.id IS NULL OR chapter_record.id IS NULL
  ) THEN RAISE EXCEPTION 'An IC14 topic does not match the frozen hierarchy.'; END IF;
END;
$validate$;

INSERT INTO public.subject_topics (
  subject_id,module_id,chapter_id,topic_number,code,title,description,
  learning_objective,practical_relevance,estimated_study_minutes,
  difficulty_level,display_order,is_exam_relevant,is_active
)
SELECT subject_record.id,module_record.id,chapter_record.id,seed.topic_number,
  seed.code,seed.title,
  'Structured study of ' || seed.title || ', covering ' || seed.focus || '.',
  'Explain, compare and apply the principal requirements and concepts concerning ' || seed.title || '.',
  'Supports compliant insurance decisions, accurate examination answers and recognition of matters requiring current official verification.',
  seed.estimated_study_minutes,seed.difficulty_level,seed.topic_number,true,true
FROM public.migration_ic14_topic_seed seed
JOIN public.subjects subject_record ON pg_catalog.upper(subject_record.code)='IC14'
JOIN public.subject_modules module_record ON module_record.subject_id=subject_record.id AND pg_catalog.upper(module_record.code)=seed.module_code
JOIN public.subject_chapters chapter_record ON chapter_record.subject_id=subject_record.id AND chapter_record.module_id=module_record.id AND pg_catalog.upper(chapter_record.code)=seed.chapter_code
WHERE NOT EXISTS (SELECT 1 FROM public.subject_topics existing WHERE pg_catalog.upper(existing.code)=seed.code);

UPDATE public.subject_topics topic_record
SET module_id=module_record.id,chapter_id=chapter_record.id,topic_number=seed.topic_number,
 title=seed.title,description='Structured study of ' || seed.title || ', covering ' || seed.focus || '.',
 learning_objective='Explain, compare and apply the principal requirements and concepts concerning ' || seed.title || '.',
 practical_relevance='Supports compliant insurance decisions, accurate examination answers and recognition of matters requiring current official verification.',
 estimated_study_minutes=seed.estimated_study_minutes,difficulty_level=seed.difficulty_level,
 display_order=seed.topic_number,is_exam_relevant=true,is_active=true,updated_at=pg_catalog.clock_timestamp()
FROM public.migration_ic14_topic_seed seed
JOIN public.subjects subject_record ON pg_catalog.upper(subject_record.code)='IC14'
JOIN public.subject_modules module_record ON module_record.subject_id=subject_record.id AND pg_catalog.upper(module_record.code)=seed.module_code
JOIN public.subject_chapters chapter_record ON chapter_record.subject_id=subject_record.id AND chapter_record.module_id=module_record.id AND pg_catalog.upper(chapter_record.code)=seed.chapter_code
WHERE topic_record.subject_id=subject_record.id AND pg_catalog.upper(topic_record.code)=seed.code;

DO $verify$
DECLARE v_subject_id bigint;
BEGIN
  SELECT id INTO v_subject_id FROM public.subjects WHERE pg_catalog.upper(code)='IC14';
  IF (SELECT pg_catalog.count(*) FROM public.subject_topics topic_record JOIN public.migration_ic14_topic_seed seed ON seed.code=pg_catalog.upper(topic_record.code) WHERE topic_record.subject_id=v_subject_id AND topic_record.is_active=true) <> 37
    THEN RAISE EXCEPTION 'Expected exactly 37 active IC14 topics.'; END IF;
END;
$verify$;

DROP TABLE IF EXISTS public.migration_ic14_topic_seed;
COMMIT;
