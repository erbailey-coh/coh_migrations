---
title: Legacy Analysis – proc_cfin_hospital_account_research_volume
source_object: cfin_fi_dm_clinical_finance/proc_cfin_hospital_account_research_volume.sql
compiled_by: codex-gpt5
compiled_on: 2025-11-06
---

# Purpose
> Source: `cfin_fi_dm_clinical_finance/proc_cfin_hospital_account_research_volume.sql` (2025-11-06)  
> Context: City of Hope clinical finance reporting – research study charge surveillance.

The legacy SQL Server stored procedure truncates and refills `dbo.cfin_Hospital_Account_Research_Volume`.  
Each refreshed row represents the **patient (non-research) hospital account** that spawned linked research hospital accounts, with charge-volume measures split across inpatient, E&M, infusion, imaging, radiation oncology, surgical, and VAD categories.

# Legacy Inputs
> Source: Same as above (lines 18-210, 340-382)  
> Purpose: Identify participating Clarity and SEM structures.

- `dbo.CLARITY_HSP_TRANSACTIONS` (+ `_2`): transaction-level charge data, research relationship columns (e.g., `rsh_chg_orig_har_id`, `rsh_chg_route_c`), reversal pointers.
- `dbo.CLARITY_HSP_ACCOUNT`, `dbo.CLARITY_ACCOUNT`, `dbo.CLARITY_ZC_ACCOUNT_TYPE`: expose guarantor type (`Client/Submitter`) used to exclude non-study accounts.
- `dbo.CLARITY_CL_COST_CNTR`: returns cost-center codes for hospital transactions.
- `dbo.CLARITY_CLARITY_TDL_TRAN`, `dbo.CLARITY_ARPB_TRANSACTIONS2`: add professional billing modifiers (POS type, modifier `95`) for telehealth logic.
- `edw_sem.patient_billing.sem_billing_transactions`: unified hospital/professional charge fact (quantities, `billing_module`, flags such as `is_em_charge`, `revenue_code`, CPT and cost-center fields).
- `dbo.CLARITY_CLARITY_RSH`, `dbo.CLARITY_zc_rsh_record_type`: joined but unused in filtering; no downstream references detected.

# Legacy Outputs
> Source: Stored procedure final insert (lines 213-382)  
> Grain: One row per `Hospital_Account_ID_Patient` (original hospital account).

Columns:
- `Hospital_Account_ID_Patient`: patient (non-research) hospital account ID (`rsh_chg_orig_har_id`).
- `Hospital_Account_ID_Research`: pipe-delimited list of research hospital accounts tied to the patient account.
- Volume metrics (all computed as `sum(case ...)` on `sem_billing_transactions.quantity`):
  - `Inpatient_Room_Quantity`: Revenue codes 110–219.
  - `EM_InPerson_Quantity` & `_Transaction_Quantity`: `is_em_charge = 1`, with transaction count using `sign(quantity)` when `amount ≠ 0`.
  - `EM_Virtual_Quantity` & `_Transaction_Quantity`: Hospital revenue code `0780` or professional POS/modifier 95 telehealth indicators.
  - `Infusion_Chemo_Quantity`, `Infusion_Quantity`, `Chemo_Quantity`: CPT bundles (`96409`, `96413`, `96416`, `96360`, `96365`, `96374`).
  - Laboratory cohorts: `Labs_Quantity` (rev 0300–0309) and `Pathology_Quantity` (rev 0310–0319).
  - Imaging cohorts: CT, MRI, MRA, PET, Ultrasound, X-ray, Mammography (diagnostic/screening), Nuclear Medicine, combined Imaging.
  - Observation hours (rev `0762`).
  - Radiation oncology groupings: Delivery, Overall, 3D, IMRT, SRS/SBRT, HDR, IORT (procedure code lists).
  - `Surgery_1Hr_Quantity`: hospital procedure codes (`36000001`…).
  - `VAD_Quantity`: hospital cost centers with CPTs `36591`, `36592`.
- `Update_DTM`: `getdate()` at execution time.

# Key Business Rules
> Source: Subquery `hb_tx_extension` logic (lines 24-83) & aggregation cases (lines 230-372).

1. **Research Eligibility** – Only include transactions where the computed `research_study_bill_group` resolves to:
   - `'Study, Bill to Research Sponsor'`
   - `'Study, Bill to Insurance (Routine)'`
   Logic inspects `rsh_chg_route_c` across original, reversal, and credit parent transactions and excludes guarantor accounts tagged `Client/Submitter`.
2. **Positive Utilization** – Subquery enforces `having sum(quantity) > 0` before string aggregation of research account IDs.
3. **Charge-Type Filtering** – Many metrics mix hospital (`billing_module = 'Hospital'`) and professional (`'Professional'`) charges, but all rely on `transaction_type = 'Charge'`.
4. **Virtual vs In-Person E&M** – Telehealth classification depends on hospital revenue code `0780` or professional POS type `2`/modifier `95`, with zero-dollar charges excluded from transaction counts.
5. **Radiation Oncology Families** – Multiple CPT ranges and discrete codes feed distinct modality counters (delivery vs general vs IMRT, etc.).

# Observations & Gaps
> Source: Repository inspection (ae-enterprise-dbt & cfin-data-models) on 2025-11-06.

- The dbt project already provides `cfin_prep.prep_research_study_bill_group`, mirroring the legacy charge-routing logic; it should anchor our migration.
- Telehealth (modifier 95 / POS type) data lives in `professional_transactions` via modifiers array and `place_of_service_type_code`; `unified_billing_transactions` drops these attributes.
- Legacy table `cfin_Hospital_Account_Research_Volume` stores a denormalized pipe-delimited field; migration should consider structured representation or document rationale for retaining format.
- Timestamp column `Update_DTM` reflects load time; Snowflake/dbt replacement should likely use `current_timestamp()` in final CTE.

# Open Questions / Assumptions
1. Confirm whether downstream consumers require the exact pipe-delimited string order for `Hospital_Account_ID_Research` or if array/list is acceptable. (Assume legacy format until advised.)
2. Validate whether professional transactions lacking modifier `95` but representing telehealth by other flags need inclusion (no legacy evidence; assume current rules sufficient).
3. Determine Snowflake data types for each metric column (likely `number(38,0)` for counts, but to be confirmed during schema design).
