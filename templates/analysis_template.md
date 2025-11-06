---
title: Analysis Template
author: codex-gpt5
compiled_on: 2025-11-06
usage: Copy into /migrations/<object>/analysis.md and replace placeholders.
---

# Purpose
> Source: `<legacy_object_path>` (retrieved `<date>`)

Summarize the business purpose, grain, and downstream consumers of the legacy object.

# Legacy Inputs
> Source: `<legacy_object_path>` (lines `<start>`-`<end>`)

- `<table_or_procedure>` — `<description>`
- ...

# Legacy Outputs
> Source: `<legacy_object_path>` (lines `<start>`-`<end>`)

- Grain: `<describe grain>`
- Columns:
  - `<column_name>`: `<definition>`
  - ...

# Key Business Rules
> Source: `<legacy_object_path>` (lines `<start>`-`<end>`)

1. `<rule summary>`
2. ...

# Observations & Gaps
> Source: Repository inspection (`<project_path>`) `<date>`

- `<observation>`
- `<gap>`

# Open Questions / Assumptions
1. `<question>`
2. ...
