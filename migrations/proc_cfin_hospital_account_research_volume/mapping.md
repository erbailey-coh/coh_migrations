---
title: Mapping – proc_cfin_hospital_account_research_volume
source_object: cfin_fi_dm_clinical_finance/proc_cfin_hospital_account_research_volume.sql
compiled_by: codex-gpt5
compiled_on: 2025-11-06
---

# Reference Materials
- Primary style rules: `docs/style_guide.md` (2025-11-06).
- Research routing prep model: `cfin-data-models/models/cfin_prep/prep_research_study_bill_group.sql`.
- Transaction fact models (ae-enterprise-dbt, 2025-11-06):
  - `hospital_transactions`
  - `professional_transactions`
  - `unified_billing_transactions`

# Legacy → Snowflake/dbt Crosswalk

| Legacy Component | Purpose in Proc | Snowflake/dbt Replacement | Notes |
| --- | --- | --- | --- |
| `CLARITY_HSP_TRANSACTIONS` & `_2` | Charge-level research routing, parent transaction resolution | `ref('prep_research_study_bill_group')` (already encapsulates `rsh_chg_route_c` logic) | Returns `patient_hospital_account_id`, `research_hospital_account_id`, and `research_study_bill_group`. |
| `CLARITY_HSP_ACCOUNT`, `CLARITY_ACCOUNT`, `ZC_ACCOUNT_TYPE` | Detect `Client/Submitter` guarantor accounts | Incorporated inside `prep_research_study_bill_group` via joins to `ae_enterprise_dbt.hospital_accounts` and `ae_enterprise_dbt.guarantor_accounts`. | No additional joins required if we rely on prep model output. |
| `edw_sem.patient_billing.sem_billing_transactions` | Unified hospital & professional charge fact | `ref('ae_enterprise_dbt', 'unified_billing_transactions')` for all billing metrics and descriptors, with a supplemental join to `ref('ae_enterprise_dbt', 'professional_transactions')` for POS type code and modifier 95 detection used in virtual visit logic. | Unified layer now covers revenue code, cost center, and E&M indicators; only telehealth fields require the professional mart. |
| `CLARITY_CL_COST_CNTR` | Supplies cost center filter for VAD metric | Already surfaced as `cost_center` in `unified_billing_transactions`; confirm same code logic. |
| `CLARITY_CLARITY_TDL_TRAN` & `CLARITY_ARPB_TRANSACTIONS2` | Provide POS type (`pos_type_c`) and telehealth modifier (`95`) | `professional_transactions` exposes `place_of_service_type_code` and `modifiers` (array of values). | Use to reproduce virtual visit rules. |
| Temp table `#rsh_acct` (string agg) | Consolidate research hospital accounts per patient account | Recreate via `listagg` over `prep_research_study_bill_group` grouped by `patient_hospital_account_id`. | Preserve `' | '` delimiter for parity unless stakeholders approve alternative. |

# Output Column Mapping

| Legacy Column | New Derivation | Source(s) | Status |
| --- | --- | --- | --- |
| `Hospital_Account_ID_Patient` | `prep_research_study_bill_group.patient_hospital_account_id` | `prep_research_study_bill_group` | Confirmed |
| `Hospital_Account_ID_Research` | `listagg(research_hospital_account_id, ' | ') within group (order by ... )` | `prep_research_study_bill_group` | Confirmed |
| Inpatient/EM/Infusion/... metrics | `sum(case ...)` replicating legacy filters using columns from `unified_billing_transactions` + `professional_transactions` | Combined fact set | Pending detailed SQL design |
| `Update_DTM` | `current_timestamp()` | dbt final CTE | Confirmed |

# Data Type Expectations

| Column | Expected Snowflake Type | Notes |
| --- | --- | --- |
| Identifiers (`Hospital_Account_ID_*`) | `number(38,0)` | Align with other hospital account models. |
| Volume metrics | `number(38,0)` | All metrics are integer counts/units. |
| `Update_DTM` | `timestamp_ntz` | Use `current_timestamp()` for deterministic load time. |

# Gaps / Follow-ups

1. Telehealth logic requires modifier detection; confirm `professional_transactions.modifiers` stores values as uppercase strings (expect `'95'`).  
2. Ensure `unified_billing_transactions` exposes `is_em_charge`, `billing_module`, and `transaction_type`. If any field is missing, supplement from base marts.  
3. Validate whether revenue code ranges should treat codes as strings vs integers in Snowflake (legacy casts to `int`; plan to use `to_number` or safe numeric comparison).  
4. Confirm duplicates when joining professional transactions by `epic_hospital_account_id` to research mapping; may need account-level distinct to prevent fan-out.
