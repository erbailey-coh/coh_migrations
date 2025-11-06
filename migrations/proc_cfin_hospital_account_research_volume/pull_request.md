---
title: Pull Request Narrative – proc_cfin_hospital_account_research_volume
author: codex-gpt5
compiled_on: 2025-11-06
source: migrations/proc_cfin_hospital_account_research_volume
---

## Summary
- Migrate legacy `proc_cfin_hospital_account_research_volume` logic into Snowflake/dbt using unified transaction sources.
- Introduce research-account aggregation metrics scoped to patient hospital accounts with study charge routing.
- Stage implementation artifacts (`cfin_hospital_account_research_volume.sql`, `.yml`) within migration workspace for review.

## Implementation Notes
- Uses `ref('prep_research_study_bill_group')` plus `ref('ae_enterprise_dbt', 'unified_billing_transactions')` with supplemental `ref('ae_enterprise_dbt', 'professional_transactions')` for telehealth routing.
- Mirrors legacy metric definitions (inpatient, E&M, infusion, imaging, radiation oncology, surgery, VAD) via deterministic Snowflake case expressions.
- Maintains legacy pipe-delimited research account list for downstream parity.

## Testing & Validation
- [ ] `dbt build --select cfin_hospital_account_research_volume` (pending)
- [ ] Metric spot-check vs legacy output (pending legacy dataset access)
- [ ] QA sign-off from clinical finance stakeholders (pending)

## Mapping Uncertainties / Follow-ups
- Confirm telehealth detection (modifier `95` and POS type `2`) meets current business expectations.
- Validate revenue code ranges and billing procedure lists against latest charge governance documentation.
- Determine whether to evolve `hospital_account_id_research` into structured array in future iteration.

## Documentation Sync
- Updated: `analysis.md`, `mapping.md`, `plan.md`, `pull_request.md`, `summary.md`.
- Outstanding: Publish finalized model + schema into `cfin-data-models` after approval; add `/docs/` reference entry.
