# Reproducibility decisions

Read when planning dependency, environment, or report changes. Adapted from
official documentation; researched 2026-09-17.

- Inspect profiles, lockfiles, manifests, runtime, and library paths. An `.Rproj`
  alone does not establish dependency isolation.
- `renv::init()` introduces a project library and activation configuration.
  `snapshot()` records dependency state; `restore()` installs the recorded state.
  Opening an activated project is distinct from restoring it.
- Initial verification found no project lockfile or `.Rprofile`. Propose renv
  adoption as an explicit environment change; record system spatial libraries too.
- Preserve `README.Rmd`; do not migrate to Quarto merely because it is supported.
- For requested Python/Quarto extensions, inspect the actual interpreter. Mixed
  R/Python reports can use knitr and reticulate and a different Python from the shell.

Sources:

- [renv introduction](https://rstudio.github.io/renv/articles/renv.html)
- [Quarto virtual environments](https://quarto.org/docs/projects/virtual-environments.html)
