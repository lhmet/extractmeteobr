# Spatial interpretation

Read for raster/polygon explanations. Retain scientific rules and fixtures in
`AGENTS.md` and `tests/testthat/test-area-weighted-mean.R`; inspect rather than
assuming their content. External sources researched 2026-09-17.

`terra::extract(..., exact = TRUE)` returns polygon-cell coverage fractions.
Fraction alone is not physical area. `terra::cellSize(..., unit = "m")` supplies
cell areas in square metres, accounting for unequal cell areas. The current
builder combines fraction and cell area into `area_weight` rather than retaining
both factors separately.

Explain numerator and available-weight denominator per polygon/layer. Observed
zeros are available; NA values are excluded from both sums. Synthetic tests cover
all-NA/all-zero layers and a small border polygon. Inspect whether zero denominators
or coverage thresholds are explicitly handled.

Explain cell indexes to value rows, polygon indexes to output rows, and layers to
dates before sparse multiplication. Reuse requires matching CRS, extent, resolution,
origin, and dimensions. Distinguish requirements from actual checks in code.

Sources:

- [terra extraction](https://rspatial.github.io/terra/reference/extract.html)
- [terra cell areas](https://rspatial.github.io/terra/reference/cellSize.html)
