---
name: plan
description: Planejar mudanças complexas neste projeto em modo somente leitura, com micro-etapas e aprovação explícita antes da implementação. Use também para /plan.
---

### Plan Mode: Collaborative Code Architecture and Refactoring

### Description

This skill activates a read-only, analytical design phase designed for complex code refactoring, architecture planning, and multi-step codebase modifications before any physical code changes are applied.

### System Prompt & Constraints

When this skill is active, you must adhere strictly to the following behavior constraints:

1. **Read-Only Context Exploration**: You are strictly in a read-only analysis phase. Explore the existing codebase, file structures, and function definitions. Do NOT generate full code implementations or overwrite files yet.
2. **Architecture Mapping**: Map out all dependencies, internal calls, and structural components of the targeted package or script that will be affected by the refactoring.
3. **Plan Proposal First**: Compile your proposed steps into a logical roadmap in the conversation. Do not write a plan file during this read-only phase.
4. **Step-by-Step Isolation**: Break down the refactoring into isolated, incremental, and micro-stepped modifications to ensure easy rollbacks and prevent breaking changes.
5. **Collaborative Validation**: Stop and explicitly ask for user confirmation and validation of the proposed architecture plan before proceeding to code generation or execution phases.

### Output Format Requirements

Every response under the /plan command must structure your output exactly as follows:

### 1. Context Assessment

* **Current State**: [Brief technical overview of the current implementation/bottlenecks]
* **Impacted Components**: [List of functions, classes, or files affected by the change]

### 2. Proposed Architecture Plan

* **Phase 1: [Name]** - [Detailed micro-step description]
* **Phase 2: [Name]** - [Detailed micro-step description]

### 3. Verification & Testing Strategy

* [How each phase will be validated, e.g., specific unit tests, linting, or edge cases]

### 4. Explicit Block Gate

* Ask for explicit approval in Portuguese. Any clear approval suffices; do not require the literal word `APPROVED`.

### Project adaptation

Read the root `AGENTS.md`. Preserve this existing project skill instead of creating
a competing planner; leave the duplicate personal skill unchanged. Translate the
four output sections above into Portuguese while retaining their structure.

Inspect `DESCRIPTION`, `NAMESPACE`, selected `R/` files, callers, consumers, tests,
`man/`, and `README.Rmd`. Use prior `references/` material when relevant, reconciled
against current behavior. Separate organization, efficiency, validation, methodology,
missing-value, and schema changes. Do not expand an isolated request into redesign.

Do not implement until the user explicitly approves the proposed plan. Do not
install dependencies, regenerate documentation, run pipelines, or execute project
code in this mode. Metadata-only runtime inspection is acceptable when needed.
When requesting approval, explain this gate comes from this `SKILL.md`, link it,
and quote the first sentence of this paragraph. Existing approval for the concrete
plan persists; do not ask again for routine steps within its scope.

For spatial planning, use the scientific invariants in `AGENTS.md`: grid geometry,
physical areas, alignment, and available-weight denominators. Specify synthetic
regression checks and numerical comparisons to run after approval, distinguishing
them from checks actually performed. Do not assume Git is available for rollback.
For dependency or report changes, read
[reproducibility guidance](references/reproducibility.md).
