---
name: doc
description: Criar documentação fiel ao código com roxygen2 para R e docstrings Google ou NumPy para Python. Use para /doc, funções, métodos científicos e exemplos; preserve README.Rmd e a interface existente.
---

# Document interfaces and scientific methods

Read `AGENTS.md`, implementation, callers, consumers, tests, and help. `/doc`
authorizes documentation edits, not changing computation to match an idealized
description. Identify discrepancies and document actual behavior.

## R documentation

Write English roxygen2 in `R/`. Follow parameter, return, methodology, equation,
units, coverage, and example requirements in `AGENTS.md`. Preserve `@return`,
Markdown-enabled roxygen, internal `@noRd`, and import conventions. Do not export
internal helpers merely to document them.

For spatial means, define all symbols, physical area units, coverage fractions,
available-weight denominators, and reuse conditions. Distinguish assumptions from
enforced checks. Describe actual classes, schemas, dates, ordering, and missing
outputs; do not invent thresholds or validations.

Create concise self-contained examples with declared objects. Use `\dontrun{}`
only for external data, credentials, downloads, or expensive processing. Edit
`README.Rmd` for interface/workflow changes; regenerate output when relevant
and feasible. Do not execute production examples simply to render documentation.

Read [documentation mechanics](references/documentation.md) for regeneration,
Rd validation, or Python style. Do not hand-edit generated `man/*.Rd` or `NAMESPACE`.
Check installed roxygen2 against `DESCRIPTION` before generation; inspect all
generated changes and avoid unexplained package-wide churn. Report generation
blockers rather than claiming unverified synchronization.

## Python and reports

If Python is requested or present, inspect its API/environment and preserve its
Google or NumPy style. Document parameters, returns, exceptions, shapes, units,
and missing values. Do not introduce Python, Shiny, Streamlit, or Quarto files to
exercise the persona. Preserve existing R Markdown unless migration is requested.

## Verification and delivery

Compare signatures/outputs with docs, verify equations/symbols, parse affected
sources/help, and run small examples where feasible. Propose behavioral fixes
separately. Report sources, generated artifacts, actual checks, and blockers in Portuguese.
