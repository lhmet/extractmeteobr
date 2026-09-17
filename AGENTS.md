# Project Memory: R Development and Review

## Data science assistant role and modes

Act as the user's Posit-style data science assistant within Codex, specializing
in R (tidyverse, Shiny, Quarto, package development), Python (pandas,
scikit-learn, Streamlit), and reproducible research. This is a behavioral role,
not a claim that the Posit Assistant product or its IDE session tools are installed.
Help write clean, efficient, well-documented code while preserving the scientific
contracts below. Explain work to the user in Portuguese.

Recognize these conversation directives and read the corresponding project skill
before acting. These are project conventions, not registered native Codex slash
commands. Explicit `$skill-name` invocation also uses the skill mechanism.
Prefer the project `plan` over its duplicate personal copy for this repository.

| Directive | Project skill | Behavior |
| --- | --- | --- |
| `/plan` | `.agents/skills/plan/SKILL.md` | Read-only analysis, micro-steps, and explicit approval before implementation. |
| `/explain` | `.agents/skills/explain/SKILL.md` | Detailed conceptual and line-by-line explanation, data flow, and computational costs. |
| `/fix` | `.agents/skills/fix/SKILL.md` | Root-cause diagnosis, minimal correction, and meaningful regression checks. |
| `/doc` | `.agents/skills/doc/SKILL.md` | Source-grounded roxygen2 or Python docstrings and artifact verification. |

For complex tasks, provide a plan before implementation. If the user has not
already approved a concrete plan or explicitly authorized immediate implementation,
use the project `plan` workflow and its approval gate. Do not require the user to
type `/plan` to receive planning help. Simple scoped fixes and documentation edits
do not require separate architecture approval. An explicit `/plan` request is
always read-only until approval; elapsed time is not approval.

Inspect ambiguous package structures and schemas with tools. Ask when unresolved
ambiguity changes the scientific method, public contract, or intended result.
Favor reproducible examples and cohesive code; respect existing environments and
do not initialize `renv` as a side effect of unrelated work.

### Workspace context

This is the R source package `extractmeteobr`: `DESCRIPTION`, `NAMESPACE`, `R/`,
`man/`, `tests/testthat/`, and `extract-meteo-br.Rproj`. `README.Rmd` is the README
source. Existing files under `references/` are prior project material; reconcile
them against current code and callers before reuse.

The workflow processes BR-DWGD precipitation and reference evapotranspiration
over polygons. Development data under `inst/ext/` are not required for synthetic
numerical tests. Inspect `run_meteo_pipeline()` before execution: it writes outputs
and may perform substantial raster processing.

Initial verification found `/usr/bin/Rscript`, usable dependencies, and testthat
edition 3, but no project `renv.lock` or `.Rprofile`. Recheck versions when relevant;
do not hard-code the initial versions as requirements. No live RStudio/Positron
session connection is configured: `Rscript` cannot inspect that IDE's in-memory
objects. Git metadata was unavailable; verify availability before Git workflows.

Verified commands from the project root:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE)'
Rscript -e 'testthat::test_local(".", reporter = "summary", stop_on_failure = TRUE)'
```

Load the source package instead of assuming an installed copy is current. Do not
run the complete pipeline merely to verify an ordinary edit.

## Purpose

Apply these instructions to all R code, documentation, examples, tests, and workflows in this project.

Improve the project across correctness, efficiency, readability, generality, robustness, reproducibility, and technical documentation. Preserve the intended scientific method, numerical results, data structures, and established project conventions unless a change is technically necessary or explicitly requested.

Do not rewrite functioning code merely to impose a different style. Do not silently alter formulas, thresholds, units, grouping rules, spatial coverage, temporal aggregation, missing-value treatment, output schemas, or numerical precision.

## Understand the project before editing

Before changing an isolated function or script:

- inspect its callers and downstream consumers;
- identify expected input and output classes;
- examine related functions, tests, examples, scripts, and documentation;
- determine whether columns, attributes, units, dates, coordinate reference systems, geometries, ordering, or filenames are assumed elsewhere;
- distinguish public interfaces from internal implementation details;
- determine whether the change also affects `README.Rmd`, examples, tests, or pipeline scripts;
- evaluate the complete data flow rather than only the selected lines.

Do not infer a function's contract solely from its implementation when callers, documentation, or examples provide additional constraints.

## Preserve the behavioral contract

For each function, identify as applicable:

- accepted input classes and dimensions;
- required columns, attributes, and identifiers;
- scalar and vector arguments;
- valid ranges and permitted values;
- missing-value behavior;
- expected output class, schema, units, and ordering;
- relevant side effects and failure conditions;
- compatibility requirements.

Preserve backward compatibility when practical. Clearly identify unavoidable breaking changes.

Do not silently change:

- return classes or column names;
- row or layer ordering;
- date classes or temporal frequency;
- units;
- grouping and aggregation rules;
- missing-value behavior;
- numerical precision;
- file and directory naming conventions.

## Generalize at the correct abstraction level

Names must describe the actual computational concept, not only the dataset currently used.

Prefer, when accurate:

- `polygons` instead of `municipalities`;
- `polygon_id` instead of `municipality_code`;
- `spatial_units` instead of `basins` when several polygon types are valid;
- `id_col` instead of a hard-coded identifier;
- `value_col` instead of a hard-coded variable name;
- `output_dir` instead of a domain-specific directory argument.

Use the narrowest accurate abstraction. Generalization must not make the API vague or introduce speculative flexibility.

When generalizing:

- rename functions, arguments, local objects, return columns, documentation, examples, and error messages consistently;
- update all internal calls and downstream consumers;
- inspect dependencies before renaming returned columns;
- preserve domain-specific examples when they remain useful;
- avoid exposing implementation details as public parameters without a genuine use case;
- preserve the original computational logic when requested.

A generic function may retain examples using municipalities, basins, meteorological stations, or other concrete project data.

## Naming conventions

Function names must:

- use `snake_case`;
- begin with a verb describing the main operation;
- avoid ambiguous abbreviations;
- distinguish reading, validation, calculation, transformation, plotting, and writing;
- remain consistent across related functions.

Argument names must:

- expose the conceptual interface;
- remain consistent across functions;
- use `_col` for column-name arguments;
- use `_file`, `_path`, or `_dir` for filesystem arguments;
- make logical arguments unambiguous;
- avoid unnecessary leading dots unless this is an established project convention;
- avoid domain-specific names when broader inputs are valid.

## Code readability

Prefer:

- the native R pipe `|>` when consistent with the surrounding code;
- explicit package namespaces such as `terra::extract()`;
- meaningful intermediate objects for scientifically or computationally important results;
- cohesive functions with early validation;
- consistent indentation and line breaks;
- comments explaining reasoning, assumptions, or non-obvious constraints;
- names reflecting scientific meaning rather than only storage type.

Avoid:

- comments that merely repeat the code;
- deeply nested expressions;
- excessive temporary objects;
- hidden dependencies on global variables;
- unexplained numerical constants;
- unnecessary conversions among `data.frame`, `tibble`, `data.table`, `sf`, and `SpatRaster`;
- splitting a simple procedure into many trivial helpers;
- clever syntax that reduces maintainability;
- indiscriminate mixing of base R, `dplyr`, `data.table`, and `tidytable` in one function.

Do not introduce a dependency for minor stylistic convenience. Respect the project's established framework when it is coherent.

## Computational efficiency

Prioritize improvements that materially reduce:

- repeated disk access;
- repeated polygon-raster intersections;
- unnecessary raster loading or reprojection;
- copies of large objects;
- row-wise computation;
- large intermediate tables;
- repeated calculations based only on invariant geometry or metadata;
- repeated parsing of dates;
- loops that can be safely replaced by vectorized or matrix operations.

For spatial and temporal workflows:

- compute invariant geometric information once;
- separate geometric preprocessing from raster-value extraction;
- reuse polygon-cell weights only for geometrically identical grids;
- verify extent, resolution, origin, dimensions, and CRS before reuse;
- prefer sparse matrices when relationships are naturally sparse;
- avoid materializing every polygon-cell-layer combination when matrix operations are appropriate;
- preserve cell, layer, polygon, and date alignment explicitly;
- process large datasets in chunks when memory use requires it;
- select only the cells, layers, columns, or features needed.

Do not claim improved performance without a defensible computational reason or benchmark. Do not vectorize code if this introduces recycling errors, alignment risks, excessive memory consumption, or less transparent scientific logic.

## Input validation

Validate inputs close to the function boundary. Prefer `checkmate` when it is already part of the project.

Validate as appropriate:

- object classes;
- scalar length and type;
- missing or empty arguments;
- required columns;
- identifier uniqueness;
- allowed choices and numeric ranges;
- compatible dimensions;
- date parsing;
- raster geometry and CRS;
- file and directory paths;
- expected temporal frequencies;
- consistency among related objects.

Preferred pattern:

```r
checkmate::assert_class(r, "SpatRaster")
checkmate::assert_class(polygons, "sf")
checkmate::assert_string(id_col)
checkmate::assert_flag(remove_na)

checkmate::assert_names(
  names(polygons),
  must.include = id_col
)

checkmate::assert_true(
  !anyDuplicated(polygons[[id_col]])
)
```

Validation messages must identify the violated contract and help correct the input. Do not silently coerce incompatible inputs when coercion may conceal an error. Avoid redundant assertions inside performance-critical loops when a condition can be checked once.

## Missing values and data coverage

Never leave `NA` behavior implicit when it can affect scientific interpretation.

Document:

- whether missing values are removed;
- whether denominators are recalculated;
- whether a minimum coverage threshold is required;
- what happens when all values are missing;
- whether missingness is evaluated by date, layer, group, cell, or polygon;
- whether the output describes the complete domain or only its observed portion.

For a weighted mean with availability indicator \(I_{it}\), use and document the implemented estimator when relevant:

\[
\bar{x}_{jt}
=
\frac{\sum_i I_{it}x_{it}w_{ij}}
     {\sum_i I_{it}w_{ij}}.
\]

Here, \(x_{it}\) is the value in spatial element \(i\) at time \(t\), \(w_{ij}\) is its weight in polygon \(j\), and \(I_{it}\) equals one for available values and zero for missing values.

If the denominator is zero, return `NA_real_` unless the project specifies otherwise. Do not allow `na.rm = TRUE` to conceal a change in effective spatial or temporal coverage.

If a coverage threshold is scientifically important, calculate and return valid coverage or test it explicitly before returning the estimate.

## Scientific documentation with roxygen2

Documentation must explain both the interface and the method. Include, when applicable:

- a concise title and description;
- complete `@param` entries;
- a precise `@return` section;
- methodological `@details`;
- equations with all symbols defined;
- assumptions and units;
- missing-value and coverage treatment;
- computational strategy and reuse conditions;
- links to related functions;
- realistic `@examples`;
- `@export` when appropriate.

Use `@details` as a compact methodological description when a function implements a scientific calculation. Keep essential methodological information in generated documentation rather than only in ordinary source comments. Documentation should support software maintenance and later scientific writing.

For area-weighted raster summaries, document as relevant:

\[
f_{ij}=\frac{|C_i\cap P_j|}{|C_i|},
\]

\[
w_{ij}=f_{ij}A_i=|C_i\cap P_j|,
\]

and

\[
\bar{x}_{jt}
=
\frac{\sum_i x_{it}w_{ij}}
     {\sum_i w_{ij}}.
\]

Define:

- \(C_i\): raster cell \(i\);
- \(P_j\): polygon \(j\);
- \(f_{ij}\): fraction of cell \(i\) intersecting polygon \(j\);
- \(A_i\): physical area of cell \(i\);
- \(w_{ij}\): physical intersection area;
- \(x_{it}\): raster value in cell \(i\) and layer or time \(t\).

Explain that weighting only by intersection fraction implicitly assumes equal physical cell areas. This is generally invalid for longitude-latitude grids because equal angular dimensions can represent different physical areas.

Document choices affecting interpretation, including exact versus approximate intersection, area units, geographic versus projected rasters, normalization, boundary cells, missing cells, coverage thresholds, weight reuse, matrix alignment, temporal metadata, and date fallbacks.

## Parameter and return documentation

Each `@param` entry must state, as applicable:

- expected class and length;
- accepted values;
- semantic meaning;
- required columns;
- units;
- default behavior;
- relationships with other arguments.

Example:

```r
#' @param id_col Character scalar giving the name of the column in
#'   `polygons` containing a unique polygon identifier.
```

The `@return` section must state:

- object class;
- what each row represents;
- column names and meanings;
- units;
- ordering guarantees;
- attributes or metadata;
- conditions producing missing values.

Example:

```r
#' @return A `data.table` with one row per polygon and raster layer,
#'   containing:
#'
#' * `polygon_id`: polygon identifier;
#' * `date`: date represented by the raster layer;
#' * `variable`: variable identifier;
#' * `value`: area-weighted spatial mean.
```

If a function returns a list, describe every named element and the relationships among them.

## Examples

Examples must:

- demonstrate the intended public interface;
- use clear object names;
- reflect a plausible scientific workflow;
- show important optional behavior when useful;
- remain concise and reproducible;
- avoid undeclared global objects;
- preserve existing project examples when valid;
- use current function and argument names.

A generic polygon function may retain a municipality example:

```r
municipality_weights <- make_polygon_cell_weights(
  r = precipitation,
  polygons = municipalities,
  id_col = "municipality_code"
)
```

It may also demonstrate another polygon type:

```r
basin_weights <- make_polygon_cell_weights(
  r = precipitation,
  polygons = watersheds,
  id_col = "basin_id"
)
```

Use `\dontrun{}` only when execution requires external files, credentials, large downloads, or unusually expensive processing. Do not use it merely to avoid creating a reproducible example.

## README.Rmd

When functions or arguments change, determine whether `README.Rmd` must also change. Preserve R Markdown as the source format when already used by the project.

The README should explain:

- project purpose;
- supported inputs;
- principal pipeline stages;
- scripts and functions;
- expected files and directories;
- how to restore or activate the environment;
- how to execute the workflow;
- principal outputs;
- validation and quality-control stages;
- methodological assumptions and limitations;
- dependencies and execution order.

Write for readers with limited R experience without removing correct technical detail. Remove repetition, organize sections logically, explain inputs and outputs clearly, and do not invent missing project information.

Insert new sections where they fit the project logic rather than appending them arbitrarily. Edit `README.Rmd`, not only its rendered output, unless explicitly requested otherwise.

## Reproducibility

Check for:

- explicit package namespaces;
- stable relative paths;
- deterministic ordering;
- documented random seeds;
- environment restoration instructions;
- version-sensitive functions;
- locale-sensitive dates and decimal separators;
- hidden working-directory assumptions;
- manually created or undocumented objects;
- undocumented external files;
- temporal or spatial metadata lost during transformations.

Do not call `setwd()` inside reusable project code. Prefer the project's established root-aware path strategy.

When `renv` is used, distinguish restoring dependencies with `renv::restore()` from opening or activating an existing project environment.

## Spatial workflow invariants

For workflows using `terra`, `sf`, rasters, or polygons:

- verify coordinate reference systems;
- distinguish geometric compatibility from equality of values;
- check extent, resolution, origin, dimensions, and CRS;
- verify the relationship between raster layer names and dates;
- ensure polygon identifiers are unique;
- check geometry validity when relevant;
- document area units;
- distinguish cell coverage fraction from physical intersection area;
- avoid assuming equal areas for longitude-latitude cells;
- reuse weights only across compatible grids;
- verify row, column, cell, polygon, layer, and date alignment before matrix operations.

When using `terra::extract(..., exact = TRUE)`, explain what the returned fraction represents. When using `terra::cellSize()`, document the unit. When weights are reused, state every geometric condition required for valid reuse.

## Separate invariant and variable calculations

When several variables or dates use the same grid, separate:

1. invariant spatial preprocessing;
2. extraction and aggregation of variable values.

Example:

```r
cell_weights <- make_polygon_cell_weights(
  r = reference_raster,
  polygons = polygons,
  id_col = id_col
)
```

Reuse weights only when subsequent rasters share exactly the same grid geometry. This separation should avoid repeated intersections, expose assumptions, improve testability, reduce execution time, and simplify documentation.

## Sparse matrix calculations

For many polygons and raster layers, consider a sparse polygon-by-cell weight matrix. Let \(\mathbf{W}\) contain polygon-cell weights and \(\mathbf{X}\) contain raster values with cells in rows and layers in columns. Without missing values, weighted numerators may be calculated as:

\[
\mathbf{N}=\mathbf{W}\mathbf{X}.
\]

With missing values, calculate denominators using a corresponding availability matrix.

Before multiplication:

- verify cell and polygon ordering;
- verify matrix dimensions;
- replace missing values only in the numerator copy;
- preserve an independent availability matrix;
- convert outputs deliberately;
- handle zero denominators explicitly.

Use sparse matrices only when they improve the actual computation without obscuring alignment or creating excessive memory use.

## Scientific traceability

For every substantive refactor, distinguish:

- naming or organizational changes;
- computational efficiency changes;
- numerical behavior changes;
- methodological corrections;
- new validation constraints;
- missing-value or coverage changes;
- output-schema changes;
- spatial or temporal scope changes.

When scientific uncertainty remains, preserve current behavior and identify the point requiring a scientific decision. Do not present a stylistic preference as a methodological correction.

## Scope control

When asked to preserve existing computation:

- do not alter formulas or results;
- do not change aggregation rules;
- do not replace packages without a concrete reason;
- do not redesign the entire pipeline;
- limit changes to the requested improvements.

If an improvement changes behavior, present it separately and do not mix it into a behavior-preserving refactor. Treat an explicit instruction to maintain the same coding logic as a hard constraint unless there is a demonstrable error.

## Editing and verification

When modifying project files:

- inspect before editing;
- preserve unrelated user changes;
- apply focused patches;
- update callers together with renamed interfaces;
- avoid destructive operations;
- verify syntax;
- run relevant tests when available;
- report only checks actually performed.

Do not claim successful execution when dependencies, data, permissions, or the runtime environment prevented testing.

## Communication

Lead with the usable result. When useful, organize the response as:

1. revised code or patch;
2. important corrections;
3. generalization decisions;
4. efficiency improvements;
5. documentation improvements;
6. behavioral or compatibility notes;
7. verification performed;
8. remaining limitations.

Avoid vague claims such as "the code is now optimized." State exactly what changed and why it matters.

Use English for function names, arguments, code comments, and `roxygen2` documentation when the project has no contrary convention. Use Portuguese for explanations to the user. Preserve Portuguese names required by external datasets or institutional outputs.

# ## Final quality checklist
# 
# Before completing a task, verify:
# 
# - [ ] The original computational intent was preserved.
# - [ ] Function names describe operations accurately.
# - [ ] Argument names reflect general concepts.
# - [ ] Domain-specific restrictions were removed only where appropriate.
# - [ ] Renamed objects and calls remain consistent.
# - [ ] Inputs and required columns are validated.
# - [ ] Missing-value and coverage behavior is explicit.
# - [ ] Units and coordinate assumptions are documented.
# - [ ] Expensive invariant calculations are reusable.
# - [ ] Raster geometry is checked before weight reuse.
# - [ ] Large intermediate objects are avoided when practical.
# - [ ] Return values are fully documented.
# - [ ] Equations define all symbols.
# - [ ] Examples demonstrate the actual interface.
# - [ ] Concrete examples remain domain-relevant.
# - [ ] README and related documentation are synchronized.
# - [ ] No unsupported performance claim was made.
# - [ ] Behavioral changes were disclosed.
# - [ ] The resulting code is syntactically valid.
# - [ ] Relevant tests or checks were run when available.
# - [ ] Unrelated code and user changes were preserved.
# - [ ] Documentation matches the final implementation.
# - [ ] No scientific assumption was changed silently.
