---
name: explain
description: Explicar código ou estrutura de pacotes com análise conceitual, linha a linha, fluxo de dados e custos computacionais. Use para /explain e pedidos de compreensão; não aplicar refatorações neste modo.
---

# Explain code and scientific workflows

Read `AGENTS.md`. Explain in Portuguese using actual source and contracts.
`/explain` requests a detailed conceptual and line-by-line walkthrough; cover the
selected scope thoroughly, grouping related lines when useful. Match requested
depth for ordinary explanations. Do not edit files or silently switch to fixing.

## Ground the explanation

Inspect the function, callers, consumers, documentation, and tests. Identify public
exports from `NAMESPACE`; source loading can expose internal functions without
making them public API. Reconcile relevant prior `references/` material with code.
Describe classes, dimensions, arguments, units, identifiers, ordering, missing
values, output schema, and side effects. Distinguish implementation, documentation,
and assumptions; a stated requirement is not necessarily validated.

Trace relevant geographic loading, aggregation, cropping, filling, weighting,
extraction, and writing. Monthly aggregation can precede `run_meteo_pipeline()`;
do not assume it executes every stage. Read
[spatial interpretation](references/spatial-interpretation.md) for weights, sparse
matrices, grid geometry, or missing observations.

## Explain the computation

Lead with purpose and a concrete input/output description. Walk through selected
lines with file references, reasoning, classes, conversions, non-standard evaluation,
and alignment. Mark illustrative numeric examples as synthetic.

Identify repeated I/O, intersections, copies, raster loading, and dense intermediate
tables where present. Give a computational reason for bottlenecks; label unmeasured
performance as a hypothesis. Separate suspected bugs and methodological questions
from style preferences.

Do not execute a full pipeline to explain it. Execute a tiny self-contained example
only to resolve a specific ambiguity without production outputs. Live IDE objects
are unavailable unless a session tool is actually connected; request a reproducible
example when files are insufficient. Conclude with material findings and unresolved
assumptions. Use `fix` for a subsequently requested correction or `plan` for redesign.
