# InsureGPTE Academic Hierarchy Freeze

**Architecture Version:** 1.6
**Status:** Approved and frozen
**Approval date:** 2026-08-10
**Scope:** Qualification levels, training programmes, programme categories,
programme sections, and subject categories

Changes to this vocabulary require a reviewed database migration, rollback,
verification SQL, frontend update, and documentation amendment.

Test deployment and acceptance steps are defined in
`docs/ACADEMIC_HIERARCHY_DEPLOYMENT.md`.

## Qualification levels

1. `licentiate` — Licentiate Exam Preparation
2. `associate` — Associate Exam Preparation
3. `fellowship` — Fellowship Exam Preparation
4. `spl_diploma` — Spl. Dip Exam Preparation
5. `surveyor` — Surveyor Exam Preparation
6. `direct_broker` — NIA - Direct Broker Exam Preparation
7. `reinsurance_broker` — NIA - Reinsurance Broker Exam Preparation
8. `composite_broker` — NIA - Composite Broker Exam Preparation

## Training programmes

### Insurance Institute of India (`iii`)

1. `iii_licentiate` — III - Licentiate Exam Preparation
2. `iii_associate` — III - Associate Exam Preparation
3. `iii_fellowship` — III - Fellowship Exam Preparation
4. `iii_spl_diploma` — III - Spl. Dip Exam Preparation
5. `iii_surveyor` — III Surveyor Exam Preparation

### National Insurance Academy (`nia`)

1. `nia_direct_general_health` — Direct Broker – General, Life and Health Training
   - Description: General, Life and Health Training
2. `nia_reinsurance_broker` — Reinsurance Broker Training
3. `nia_composite_broker` — Composite Broker Training

There is no standalone Life Broker programme. Life Broker content belongs to
Direct Broker. Composite Broker remains the combined Direct Broker and
Reinsurance Broker pathway.

## Programme categories

1. `professional_qualification`
2. `broker_exam`
3. `surveyor_exam`
4. `specialized_diploma_exam`

## Programme sections

1. `compulsory` — Compulsory
2. `compulsory_optional` — Compulsory Optional
3. `optional_credit` — Optional Credit
4. `general_insurance` — General Insurance
5. `life_insurance` — Life Insurance
6. `reinsurance` — Reinsurance
7. `broker` — Broker
8. `surveyor` — Surveyor
9. `spl_diploma` — Spl_Diploma

Section codes are globally controlled but records remain scoped to a training
programme through `(training_programme_id, code)`.

## Subject categories

`subjects.category` is restricted to exactly these values:

1. General Insurance
2. Life Insurance
3. Common (Life & Non-Life)
4. Regulation and Compliance

Legacy `Common`, `Common Subject`, and `Foundation` values normalize to
`Common (Life & Non-Life)` during deployment.

The Admin interface uses a required dropdown. Custom category values are not
accepted by the Admin form, CSV bulk upload, or database constraint.

## Approved hierarchy relationships

- Each subject belongs to one approved qualification level and one approved
  training programme.
- A selected programme section must belong to the selected programme.
- Direct Broker contains both General Insurance and Life Insurance sections.
- Reinsurance Broker contains the Reinsurance section.
- Composite Broker contains General Insurance, Life Insurance, and Reinsurance.
- Surveyor content uses the Surveyor section.
- Specialised Diploma content uses the Spl_Diploma section.
