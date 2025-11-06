# AGENTS.md

This document defines **behavioral and operational rules** for AI coding agents working in this repository. It does **not** define technical migration rules. All migration logic, SQL-to-dbt mappings, and Snowflake conventions should be documented separately in `/docs/`. The agent must always reference those documents when performing code translation or implementation tasks. If documentation for a topic does not exist, use context7 (see below) to retrieve relevant documentation.

---

## Primary directive

Operate as a disciplined assistant that transforms and manages code, documentation, and workflow **without inventing business logic**. Always ground reasoning in the authoritative sources located in `/docs/`.

---

## Behavior rules

1. **Reference first, act second**: Before producing code or transformations, search `/docs/` for relevant specifications, style guides, or mapping rules.
2. **Never improvise logic**: If required information is missing, either:

   * request clarification, or
   * create a documentation task to extend `/docs/`.
3. **Version control awareness**: All generated content should be committed in small, reviewable changes with descriptive messages.
4. **No destructive edits**: Never remove files, schemas, or tests unless explicitly directed by a documented rule.
5. **Use deterministic output**: Produce reproducible SQL and dbt artifacts; avoid random seeds or nondeterministic ordering.
6. **Privacy and security**: Treat all PHI/PII as confidential; redact sample data; never output secrets or credentials.
7. **Clarity and auditability**: Annotate every code block and document section with its source, purpose, and date.

---

## Context7-assisted documentation

When information gaps exist and `/docs/` lacks authoritative coverage, use Context7 to expand documentation responsibly.

### Process overview

1. Construct a query to Context7 using the base endpoint:
   `https://context7.com/websites/snowflake_en/llms.txt?topic=<topic>&tokens=10000`

   * Replace `<topic>` with a concise description, e.g. `how+to+use+qualify`.
2. Retrieve the text response and save it to `/docs` as Markdown.

   * Filename: kebab-case of the topic, e.g. `snowflake-how-to-use-qualify.md`.
3. Reference the new file in `/docs/index.md` and relevant model documentation. If `index.md` does not exist, create it and ensure it is up to date.

### Usage rules

* Only use Context7 for **supplementary context**, not authoritative guidance.
* Never auto-apply undocumented SQL behavior; record findings and await verification.
* If contradictions arise between Context7 and official docs, **prefer official docs** and flag the discrepancy.

---

## Interaction with `/docs`

### Style precedence

* The file `/docs/style_guide.md` contains **City of Hope-specific dbt style rules**.

* These rules take **absolute precedence** over any other documentation in `/docs/`.

* The agent must conform exactly to `/docs/style_guide.md` when generating, modifying, or reviewing dbt models.

* If conflicts occur between `/docs/style_guide.md` and other references, apply the style guide's directive and record the deviation in the commit message.

* Do not overwrite or reinterpret these standards; adhere strictly to the prescribed structure, naming, and formatting.

* All domain logic, naming conventions, data types, and SQL transformations reside in `/docs/`.

* `/docs` is the single source of truth for migration and implementation rules.

* When encountering outdated or missing content in `/docs/`, create or update Markdown files to fill the gap. Include provenance metadata in front matter.

* Agents must not embed migration details directly in this AGENTS.md.

### Documentation maintenance

* Treat documentation updates as part of every change request. When code or SQL logic moves, sync the corresponding guides, mappings, tests, and examples in `/docs/` so the written guidance reflects the latest Snowflake/dbt reality.
* Add crosswalks, lineage notes, and verification steps to the appropriate subdirectories (for example `/docs/mappings/` or `/docs/tests/`) and reference them from `/docs/index.md` once that index exists.
* Capture the authoritative sources (official docs, existing repository logic, Context7 extracts) in each updated file so successors can audit decisions quickly.
* When legacy content is replaced, either revise it in place or add a deprecation note that points to the new canonical path. Avoid leaving conflicting instructions.

---

## Codebase awareness and mapping behavior

The agent must use the code in the following folders to understand both the legacy SQL Server system and the Snowflake + dbt implementation, and to map logic correctly:

* **`/cfin_fi_dm_clinical_finance/`** - legacy SQL Server objects (procedures, functions, views). Treat as the historical source of logic only.
* **`/ae-enterprise-dbt/`** - Snowflake-targeted dbt project. Treat as the primary reference for current Snowflake sources, models, macros, tests.
* **`/cfin-data-models`** - Clinical Finance-specific dbt project for City of Hope.
* **`/migrations/`** - working directory for active migration efforts. Each migration must live in its own subfolder.

> **Unified-first source hierarchy (2025-11-06 · codex-gpt5)**  
> Within `ae-enterprise-dbt`, prioritize models in `models/unified/`—especially relations prefixed `unified_`. Only fall back to curated marts if the unified layer lacks required attributes, and explore other directories or `cfin-data-models` sources last. Document any exceptions in migration notes.

> **Migration work area only (2025-11-06 · codex-gpt5)**  
> Treat `/ae-enterprise-dbt`, `/cfin-data-models`, and `/docs` as read-only references during migrations. Draft new SQL, YAML, and documentation inside the relevant `/migrations/<object>/` subdirectory. Move vetted artifacts into the project trees only after review and approval.

> **Migration templates (2025-11-06 · codex-gpt5)**  
> When creating `analysis.md`, `mapping.md`, `plan.md`, `pull_request.md`, `summary.md`, or additional artifacts, start from the corresponding markdown templates in `/templates/`. Customize placeholders but retain required sections and metadata.

### Required actions before any change

1. **Inventory structures**

   * From SQL Server: identify object names, inputs, outputs, keys, and business rules.
   * From Snowflake/dbt: inspect `models/`, `sources.yml`, and `macros/` to locate the **authoritative Snowflake tables and views**.
2. **Select Snowflake tables via dbt**

   * Use `{{ source() }}` and `{{ ref() }}` to access Snowflake objects defined in dbt. Do not hardcode database or schema names.
3. **Column and type mapping**

   * Expect different schemas and column names between SQL Server and Snowflake. Map explicitly, with casts where needed.
   * If a one-to-one mapping is not evident, flag uncertainty (see below) and request guidance.

### Uncertainty protocol

* When unsure about a mapping or source selection:

  * Add a **Mapping Uncertainty** section in the PR description listing the ambiguous items and proposed interpretations.
  * Inline `TODO(clarify)` comments at the precise lines.
  * Notify the requester with a concise set of questions.
  * Do not proceed with irreversible changes until confirmed.

### Validation expectations

* Verify that chosen Snowflake tables are appropriate by checking `sources.yml` definitions, tests, and owners.
* Run targeted builds and tests on the impacted models only. Attach sample comparisons or aggregate checks to the PR when feasible.
* Use Snowflake-appropriate syntax at all times; do not rely on SQL Server-specific behavior.

---

## Migration workflow standard

When initiating a new migration, the agent must create a dedicated workspace and documentation set so the effort is auditable end to end.

1. **Workspace scaffold**
   * Create a directory under `/migrations/<ticket-or-object-name>/`.
   * Start with the following Markdown files:
     * `analysis.md` — legacy object overview, purpose, dependencies, upstream/downstream consumers, outstanding questions.
     * `mapping.md` — column-by-column (or logic block) crosswalk from SQL Server sources to target Snowflake/dbt sources using `source()`/`ref()`. Highlight gaps or assumptions.
     * `plan.md` — proposed migration strategy, dbt model structure, test coverage, validation approach, and rollout steps.
     * `pull_request.md` — standardized PR description capturing summary, testing notes, validation status, and mapping uncertainties.
     * `summary.md` — concise business-facing synopsis of the migration outcome, key metrics, and follow-up actions.
2. **Detailed analysis**
   * Document the legacy SQL (include file path/reference) and enumerate each source table/view, key business rule, filters, aggregations, and edge cases.
   * Record inputs and expected outputs, data volumes, and any performance or scheduling considerations.
3. **Source mapping**
   * For every legacy source element, identify candidate Snowflake objects and supporting dbt resources. Note verification steps required to confirm availability and correctness.
   * Reference any existing `/docs/mappings/` or create new entries if the mapping is novel.
4. **Plan finalization**
   * Collaborate with the requester to approve the `plan.md` contents before writing code. Capture decisions, open questions, and acceptance criteria.
5. **Implementation**
   * Once the plan is agreed, create the dbt model file and corresponding `schema.yml` tests in the appropriate project (`ae-enterprise-dbt` or `cfin-data-models`). Track their paths inside the migration docs.
   * Update `/docs/` (style guides, mappings, tests, index) in parallel so canonical documentation reflects the new model.
6. **Synchronization**
   * Keep `analysis.md`, `mapping.md`, `plan.md`, the dbt model, and `schema.yml` in sync as changes are made—whether by the agent or the user.
   * When the user edits one artifact, reconcile the rest in the same change set before proceeding.
7. **Closure**
   * Ensure all decisions, validations, and final SQL snippets are captured in the migration folder.
   * Link or merge relevant findings back into `/docs/` so future migrations can leverage the knowledge.
   * Mark any superseded legacy documentation as deprecated or update it with references to the new Snowflake implementation.

---

## Output expectations

* Code: clean, modular, and fully commented per `/docs/style_guide.md`.
* Commits: atomic and traceable; include issue or task reference if available.
* Documentation: structured with headings, reproducible examples, and verified references.

---

## Review checklist

- ✅ Migration workspace: `/migrations/<object>/analysis.md`, `mapping.md`, and `plan.md` are complete, current, and reference supporting `/docs/` material.
- ✅ Documentation sync: `/docs/` guides, mappings, and index reflect the latest Snowflake/dbt implementation; deprecated legacy notes are flagged.
- ✅ Style compliance: dbt model SQL and `schema.yml` follow `/docs/style_guide.md`, including naming, formatting, and test conventions.
- ✅ Source mapping: Every legacy column/logic block is tied to a Snowflake `source()`/`ref()` with assumptions or open questions clearly documented.
- ✅ Validation: Planned or executed tests (dbt, data quality, comparisons) are recorded with outcomes or follow-up actions.
- ✅ Commit readiness: Changes are organized into reviewable commits with descriptive messages and outstanding actions captured as TODOs or follow-up tasks.

---

## Summary

The AGENTS.md defines **how** the agent behaves, not **what** business logic to apply. The `/docs/` directory contains the migration rules, conventions, and mappings. Always reference, never invent.

---

## Living document policy

Agents may extend this AGENTS.md when they discover repeatable practices, caveats, or governance steps that future agents should follow. Each addition must:

* Explain the intent and scope of the instruction in plain language.
* Cite the supporting material in `/docs/` (or note that the agent created it during the task).
* Include the date and author agent identifier in parentheses so the evolution of the policy is traceable.

Do not remove existing instructions without an explicit request from a repository maintainer; add clarifications or superseding guidance instead, and mark the older text as deprecated if necessary.


