---
title: Implementation Plan – proc_cfin_hospital_account_research_volume Migration
source_object: cfin_fi_dm_clinical_finance/proc_cfin_hospital_account_research_volume.sql
compiled_by: codex-gpt5
compiled_on: 2025-11-06
---

# Objective
Deliver a dbt model within `cfin-data-models` that reproduces the legacy research charge volume metrics per patient hospital account, adhering to `docs/style_guide.md`.

# Proposed Target Artifacts
1. **Model**: `models/cfin_models/financial/cfin_hospital_account_research_volume.sql`
   - Materialization: `table` (to mirror legacy truncate+load).
   - Grain: 1 row per `patient_hospital_account_id`.
2. **Schema YAML**: `models/cfin_models/financial/schema/cfin_hospital_account_research_volume.yml`
   - Enforce contracts, column descriptions, `number(38,0)` metrics, PK tests on patient account.
3. **Documentation Sync**: Update `/docs/` with a migration note describing the Snowflake implementation (after model stabilized).

# High-Level Steps
1. **Curate Research Mapping**
   - Use `ref('prep_research_study_bill_group')` to obtain eligible research transactions.
   - Aggregate to:
     - Mapping CTE (`research_charge_mapping`) keyed by `patient_hospital_account_id`, `research_hospital_account_id`, and `tx_id`.
     - Account-level listagg CTE for `Hospital_Account_ID_Research`.
2. **Assemble Charge Fact Set**
   - Start from `ref('ae_enterprise_dbt', 'unified_billing_transactions')`.
   - Left join `research_charge_mapping` on `epic_hospital_tx_id = tx_id` **or** `epic_hospital_account_id = research_hospital_account_id`.
   - Supplement telehealth attributes by joining `ref('ae_enterprise_dbt', 'professional_transactions')` (for POS type codes and modifier arrays) where `billing_module = 'Professional'`.
   - Filter to `transaction_type = 'Charge'` and retain only rows tied to a mapped patient account.
3. **Compute Metrics**
   - Recreate each `sum(case ...)` using Snowflake syntax with explicit numeric comparisons (`to_number(revenue_code)` where necessary).
   - Use boolean helper columns to simplify repeated telehealth / infusion / imaging categorization.
4. **Finalize Output**
   - Build final CTE with all metrics, `Hospital_Account_ID_Patient`, aggregated research list, and `current_timestamp()` as `update_dtm`.
   - Apply `{{ generate_surrogate_key(['patient_hospital_account_id']) }}` if we need an internal key (optional; legacy table lacked one).
5. **Schema & Tests**
   - Define YAML contract with column descriptions referencing legacy behavior.
   - Add `unique` + `not_null` tests on patient account; include `not_null` tests for each metric (if business expects zero-filled, otherwise optional).
6. **Validation**
   - Run `dbt build --select cfin_hospital_account_research_volume`.
   - Perform reconciliation: compare aggregate sums vs legacy SQL output (if accessible) or sanity-check counts (to be coordinated with stakeholders).
7. **Documentation**
   - Draft `/docs/` entry summarizing mapping, dependencies, and validation outcomes; link from `index.md` once available.

# Dependencies & Risks
- Telehealth logic requires accurate modifiers/POS fields; confirm availability before coding.
- Joining professional transactions by account may introduce duplicates; must deduplicate via `distinct` mapping or transaction key.
- Need to maintain deterministic ordering in `listagg` to mimic legacy `string_agg(... order by hsp_account_id)`.

# Approval Checkpoints
1. Review this plan with data owners before implementing metric logic.
2. Confirm acceptance of table location (`schema = financial`) and materialization.
3. Validate column data types with downstream consumers prior to contract enforcement.
