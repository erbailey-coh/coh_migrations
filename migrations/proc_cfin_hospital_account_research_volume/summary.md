---
title: Migration Summary – proc_cfin_hospital_account_research_volume
author: codex-gpt5
compiled_on: 2025-11-06
source: migrations/proc_cfin_hospital_account_research_volume
---

# Objective
Recreate the legacy SQL Server procedure that populated `cfin_Hospital_Account_Research_Volume` by delivering a Snowflake/dbt model driven by unified hospital and professional billing transactions.

# Source & Target Paths
- Legacy source: `cfin_fi_dm_clinical_finance/proc_cfin_hospital_account_research_volume.sql`
- dbt model location: `cfin-data-models/models/cfin_models/financial/cfin_hospital_account_research_volume.sql`
- dbt schema location: `cfin-data-models/models/cfin_models/financial/schemas/cfin_hospital_account_research_volume.yml`

# Key Outcomes
- Established patient-level research account aggregation using `prep_research_study_bill_group` and unified billing models.
- Replicated 30+ charge volume metrics (E&M, infusion, imaging, radiation oncology, surgery, VAD) with Snowflake-compatible logic.
- Preserved legacy pipe-delimited research account listings to minimize downstream disruption.
- Staged draft model (`cfin_hospital_account_research_volume.sql`) and contract (`cfin_hospital_account_research_volume.yml`) inside the migration workspace for review.

# Next Steps
1. Execute targeted `dbt build` to validate the model and contract.
2. Compare metric totals against historical procedure output to confirm parity.
3. Socialize results with clinical finance stakeholders; capture sign-off or adjustments.
4. Promote approved SQL/YAML into `cfin-data-models` and document the canonical implementation in `/docs/`.
5. Retire or annotate the legacy SQL Server procedure once Snowflake deployment is accepted.
