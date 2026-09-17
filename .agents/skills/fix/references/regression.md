# Regression checks

Read when selecting tests. Adapted from official testthat documentation and project
fixtures; researched 2026-09-17.

`DESCRIPTION` selects edition 3. `test_local()` tests source; `test_package()` tests
an installed package; `test_check()` belongs to package checking. Keep the runner.

Target the weighted-mean suite from the root when relevant:

```sh
Rscript -e 'testthat::test_local(".", filter = "area-weighted-mean", reporter = "summary", stop_on_failure = TRUE)'
```

Omit `filter` for the full suite. Check arguments if versions differ. Use justified
floating-point tolerances and explicit class/schema assertions. Edition 3 surfaces
unhandled messages/warnings; do not suppress them without understanding them.

`make_area_weighted_fixture()` provides a geographic 3-by-3 raster, monthly layers,
partial intersections, zero, NA, all-NA/all-zero layers, and a small border polygon.
Reuse within tests; it is not exported package functionality.

The explicit mean helper reuses production weights: it verifies aggregation but
is not an independent oracle for weight construction. For weight defects, derive
geometry/area expectations independently. Preserve cell/polygon/layer/date/variable
alignment and existing `1e-12` tolerance absent numerical justification.

Sources:

- [Running package tests](https://testthat.r-lib.org/reference/test_package.html)
- [testthat edition 3](https://testthat.r-lib.org/articles/third-edition.html)
