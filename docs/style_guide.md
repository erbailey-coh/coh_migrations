# City of Hope dbt Coding Rules — For AI Assistants

> Purpose: A concise rulebook for generating **acceptable** dbt models at City of Hope. Follow exactly. No exceptions without explicit instruction.

## 0) Golden Rules

* **Never use abbreviations in CTE names.**
* **Never use table aliases in SQL statements.** Prefix all columns with the full relation/CTE name when >1 table involved.
* One model = one clear grain. Enforce via contracts and tests.

## 1) Inputs you must request/assume

* Business purpose and domain (clinical finance context).
* Grain and primary key.
* Materialization (table/view/incremental) and rationale.
* Watermark column for incremental and `unique_key`.
* List of required source tables and fields only.

## 2) File layout and scaffolding

Create:

* `models/<folder>/<model>.sql`
* `models/<folder>/schema/<model>.yml`

## 3) Model SQL structure (strict)

* Top section: config block with `materialized`, `schema`, optional `alias`, `unique_key` when incremental.
* CTE ordering:

  1. **sources**: all `source()` imports. Minimal columns only.
  2. **staging**: type casting, normalization, filters.
  3. **business logic**: joins and calculations.
  4. **final**: one CTE that matches the declared grain.
* The last statement is `select ... from final`.
* Keywords lowercase. Indent 4 spaces. Trailing commas. Explicit `as` for column aliases.

### CTE naming rules

* `clarity_hospital_account_source` not `ha_src`.
* `positive_charges_filtered` not `pos_chg`.
* `hospital_account_with_charge_rollup` not `ha_rollup`.

### Join rules

* Write join type explicitly. Join left-to-right.
* No table aliases. Use full CTE names in `on` and `select`.
* Prefer `union all`.

### Aggregations and windows

* Guard aggregations with explicit grouping lists.
* Use `qualify` to filter window functions.

## 4) Keys and surrogate keys

* Primary key naming: `<object>_key`.
* Use `{{ generate_surrogate_key(["<stable_id>", ...]) }}`.
* Include lineage keys for audit: `patient_key`, `encounter_key`, `hospital_account_key` when relevant.

## 5) Incremental models

* Only when data is large or slowly changing.
* Config: `materialized='incremental'`, `unique_key`, and watermark.
* Use `merge` strategy. Implement `is_incremental()` filters.

## 6) YAML schema rules (mandatory)

* Enforce contracts: `contract.enforced: true`.
* Every column:

  * `description` is information-rich (no circular definitions). Example anti-pattern: `diagnosis_line_number: "The line number associated with the diagnosis"`.
  * `data_type` set to Snowflake type.
  * Add tests for PK uniqueness and `not_null`.
* Flag PHI with `meta.is_phi: true` and state `intended_consumers`.

## 7) PHI and compliance

* Retain PHI in curated source-of-truth models when clinically/financially relevant.
* Rely on Snowflake role-based access. Do not expose PHI in public/adhoc views.

## 8) Linting, tests, and validation

* Pass SQLFluff (Snowflake + dbt templater). No unexplained `-- noqa`.
* Tests: primary key `unique` + `not_null`. Add integrity tests for critical FKs.
* Compare to production with defer. Document acceptable row/KPI deltas.

## 9) Disallowed patterns

* Abbreviated CTE names.
* Table aliases.
* `select *` in production models.
* Hidden cross joins. Unqualified columns in multi-table selects.

## 10) Minimal templates

### Model template

```sql
{{ config(
    materialized = 'table',
    schema = 'cfin_data_models',
    alias = 'hospital_account_activity'
) }}

-- Model: cfin_hospital_account_activity
-- Purpose: Aggregate positive-charge activity to one row per hospital account.
-- Grain: 1 row per hospital_account_key
-- PK: hospital_account_key

with clarity_hospital_account_source as (
    select
        hospital_account_id,
        patient_id,
        admission_date,
        discharge_date
    from {{ source('clarity', 'hospital_account') }}
),

clarity_charge_source as (
    select
        hospital_account_id,
        charge_code,
        charge_amount,
        charge_date
    from {{ source('clarity', 'charge') }}
    where charge_amount > 0
),

hospital_account_with_charge_rollup as (
    select
        clarity_hospital_account_source.hospital_account_id as hospital_account_id,
        clarity_hospital_account_source.patient_id as patient_id,
        count(distinct clarity_charge_source.charge_code) as total_charge_types,
        sum(clarity_charge_source.charge_amount) as total_charge_amount,
        min(clarity_charge_source.charge_date) as first_charge_date,
        max(clarity_charge_source.charge_date) as last_charge_date
    from clarity_hospital_account_source
    left join clarity_charge_source
        on clarity_hospital_account_source.hospital_account_id = clarity_charge_source.hospital_account_id
    group by
        clarity_hospital_account_source.hospital_account_id,
        clarity_hospital_account_source.patient_id
),

final as (
    select
        {{ generate_surrogate_key(['hospital_account_id']) }} as hospital_account_key,
        hospital_account_id,
        patient_id,
        total_charge_types,
        total_charge_amount,
        first_charge_date,
        last_charge_date,
        current_timestamp() as record_updated_at
    from hospital_account_with_charge_rollup
)

select * from final;
```

### Schema template

```yaml
version: 2

models:
  - name: cfin_hospital_account_activity
    description: |
      Aggregates positive-charge activity to one row per hospital account for
      clinical finance analysis of utilization and charge mix.
    config:
      contract:
        enforced: true
    columns:
      - name: hospital_account_key
        description: |
          Surrogate key for the hospital account row. Enables lineage, joins,
          and de-identification in downstream marts.
        data_type: number(38,0)
        tests: [unique, not_null]

      - name: hospital_account_id
        description: |
          Source hospital account identifier used for billing and encounter
          grouping. Retained for audit and reconciliation.
        data_type: number(38,0)
        meta: {is_phi: true, intended_consumers: [internal_curated]}
        tests: [not_null]

      - name: patient_id
        description: |
          Source patient identifier linked to the hospital account. Supports
          patient-level rollups. Mask or remove in external views.
        data_type: number(38,0)
        meta: {is_phi: true, intended_consumers: [internal_curated]}

      - name: total_charge_types
        description: Count of distinct positive-charge codes on the account.
        data_type: number(38,0)

      - name: total_charge_amount
        description: Sum of positive charge amounts on the account.
        data_type: number(38,2)

      - name: first_charge_date
        description: Earliest date with a positive charge on the account.
        data_type: date

      - name: last_charge_date
        description: Latest date with a positive charge on the account.
        data_type: date

      - name: record_updated_at
        description: Timestamp when this row was stamped in this model.
        data_type: timestamp_ntz
        tests: [not_null]
```

Adhere to these rules to produce code that can be merged with minimal rework.

## 11) Source selection hierarchy

* 2025-11-06 (codex-gpt5) — When working inside `ae-enterprise-dbt`, prefer models in `models/unified/` (relations named `unified_*`). If the unified layer lacks the needed fields, step down to the curated `marts/` directory, and reach for other project sources only as a last resort. Capture any exceptions in migration documentation.

## 12) Migration staging protocol

* 2025-11-06 (codex-gpt5) — Treat `/ae-enterprise-dbt`, `/cfin-data-models`, and `/docs` as reference libraries while designing migrations. Create or revise SQL, YAML, and supporting notes in the active `/migrations/<object>/` workspace until changes are reviewed and approved for promotion into the main projects.
