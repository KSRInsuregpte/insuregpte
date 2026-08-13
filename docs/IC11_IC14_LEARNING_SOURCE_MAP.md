# IC11 and IC14 Learning Content Source Map

## Purpose

This record governs preparation of the IC11 and IC14 Learning Module content.
The source PDFs remain outside the repository and are not redistributed. Learning
notes, revision notes, and flashcards must be written as original summaries.

## Supplied source register

| Subject | Source | Pages | Source status | SHA-256 |
| --- | --- | ---: | --- | --- |
| IC11 | `IC-11-practises of general insurance 2011.pdf` | 287 | Insurance Institute of India course text, first edition 2011 | `16A8A7AE3D7087061A4FC9FE9263B639A7BDB0A24DA23E8C4A0005ED344AE1EF` |
| IC14 | `IC-14-regulations (1).pdf` | 320 | Insurance Institute of India course text, first edition 2011 | `63A163C75D6D81BA5E2CA272ABC70C7012F5DFBC996470F7770328D64180FB53` |
| IC14 | `IC-14-new_Addendum - Regulation of Insurance - III.pdf` | 14 | III addendum uploaded 7 August 2023 | `F14AECCEC7D0A28783C74C5577837E68A403E949851347F2CC1D9F2DEFF6C884` |

## Source precedence

1. The IC14 addendum supersedes the IC14 base course text wherever the two conflict.
2. Unaffected concepts and syllabus coverage continue to follow the applicable base course text.
3. Time-sensitive regulatory facts must be identified during drafting. They require
   current official-source verification before publication, while the III wording is
   retained as the examination reference where appropriate.
4. Apparent typographical errors in a source are not repeated as learning content.

## Existing database hierarchy mapping

### IC11 - Practice of General Insurance

| Database chapter | Primary course coverage |
| --- | --- |
| IC11-C01 - Insurance Legislation | Chapter 1 legal and regulatory framework material |
| IC11-C02 - Insurance Market | Chapter 1 Indian and international market structure and insurance roles |
| IC11-C03 - Insurance Forms | Chapter 2 Policy Documents and Forms |
| IC11-C04 - Fire and Marine Insurance Coverages | Chapter 3 Fire and Marine Insurance |
| IC11-C05 - Miscellaneous Coverages | Chapter 4 and the relevant non-engineering classes in Chapter 5 |
| IC11-C06 - Specialised Insurances | Specialised and engineering classes in Chapter 5 |
| IC11-C07 - Underwriting, Rating and Premium | Chapters 6 and 7 |
| IC11-C08 - Claims | Chapter 8 |
| IC11-C09 - Investment and Accounting | Chapter 9 Insurance Reserves and Accounting, with the frozen database description governing scope |

### IC14 - Regulations of Insurance Business

| Database chapter | Primary course coverage |
| --- | --- |
| IC14-C01 - Insurance Regulatory Framework | Chapter 1 Development of Insurance Legislation in India and Insurance Act 1938 |
| IC14-C02 - IRDAI and Insurance Legislation | Chapter 2 IRDA Functions and Insurance Councils |
| IC14-C03 - Registration and Licensing | Chapter 3 licensing functions |
| IC14-C04 - Distribution and Market Conduct | Chapter 4 conduct-of-business material and applicable Chapter 3 intermediary material |
| IC14-C05 - Policyholder Protection | Chapter 5 assignment, nomination and transfer, plus relevant servicing rights |
| IC14-C06 - Claims and Consumer Protection | Chapter 6 Protection of Policyholder Interests and relevant claims rules |
| IC14-C07 - Grievance Redressal | Chapter 7 dispute resolution, the grievance annexure, and applicable addendum changes |
| IC14-C08 - Financial and Solvency Regulations | Chapter 8 solvency margin and investments |
| IC14-C09 - International Insurance Regulation | Chapter 9 international trends |

## IC14 addendum controls

The 7 August 2023 addendum changes examination material relating to:

- Consumer commission pecuniary limits and the three-tier structure;
- appeal periods and required deposits;
- the Insurance Ombudsman relief threshold;
- the insurance-sector foreign direct investment limit;
- theoretical and practical training hours for insurance broker personnel; and
- minimum capital for direct, reinsurance, and composite brokers.

These changes principally affect IC14-C01, IC14-C03, and IC14-C07 in the frozen
database hierarchy. Content migrations must not restore the superseded base-text
figures.

## Content-production rule

Each approved topic will receive one detailed learning note, one quick-revision
note, and three flashcards, following the accepted IC01 interaction model. Stable
codes, idempotent migrations, rollback scripts, and verification SQL are required.
