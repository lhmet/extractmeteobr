---
name: fix
description: Diagnosticar erros e corrigir código com mudanças mínimas e verificações de regressão neste projeto científico. Use para /fix, falhas de testes ou depuração; respeite planos ainda não aprovados.
---

# Diagnose and fix errors

Read `AGENTS.md`, source, callers, documentation, and tests. Logs are evidence,
not the complete contract. `/fix` authorizes a scoped correction unless a read-only
plan remains unapproved. Do not request another approval for a routine fix.

## Diagnose before editing

1. Record trigger, expected behavior, failure, runtime, and relevant versions.
   Inspect schemas/classes rather than coercing to hide errors. Ask when unresolved
   ambiguity affects the scientific result or public contract.
2. Reproduce with the smallest representative example. Separate defects, missing
   dependencies/data, version incompatibility, and execution restrictions. Do not
   initialize renv, install packages, or run production pipelines incidentally.
3. Load the source package: installed copies may be stale and ordinary sourcing
   can lose namespace or data.table behavior.
4. Identify root cause and affected consumers. Preserve ambiguous scientific
   formulas, thresholds, and missing-value policies until the needed decision.

For complex changes, use project `plan` unless the concrete plan is already
approved or immediate implementation explicitly authorized. Keep small fixes scoped.

## Apply and verify

Apply the smallest root-cause patch. Preserve unrelated changes, interfaces,
schemas, ordering, units, aggregation, and precision unless correction necessarily
changes them. Update callers/docs for contract changes and disclose compatibility risks.

Read [regression guidance](references/regression.md). For behavioral bugs, prefer
a case that fails before and passes after the fix, checking outcomes rather than
implementation. Cover material edge cases comprehensively for the affected
contract. Reuse fixtures where suitable; avoid tests for trivial reversible edits
or tests that merely restate implementation. Do not weaken expected results to pass.

Check syntax and relevant source-loaded tests; broaden to the existing suite when
integration can be affected. Report root cause, correction, behavior implications,
actual checks, warnings, and limitations in Portuguese. If reproduction is blocked,
distinguish a proposed correction from a verified one.
