# VALIDATE RS RESULTS WITHIN THE SOUTH REGION ----
#
# Prerequisite: run run_meteo_pipeline() twice with the same file_stem
# ("municipal-monthly-meteorology", the default), once with
# `states = "sul"` and once with `states = "rs"`, so that both
# `municipal-monthly-meteorology-sul.fst` and
# `municipal-monthly-meteorology-rs.fst` exist under `data/processed`.
# validate_regional_consistency() itself does not depend on any
# extractmeteobr function, so no API changes were required here.

source(here::here("inst/validation/validate-regional-consistency.R"))

sul <- fst::read_fst(
  here::here(
    "data/processed/municipal-monthly-meteorology-sul.fst"
  )
) |>
  tibble::as_tibble()

rs <- fst::read_fst(
  here::here(
    "data/processed/municipal-monthly-meteorology-rs.fst"
  )
) |>
  tibble::as_tibble()

regional_consistency <- validate_regional_consistency(
  regional_data = sul,
  state_data = rs,
  state = "rs",
  variables = c("pr", "ETo"),
  key_cols = c("polygon_id", "date"),
  state_col = "state",
  tolerance = 1e-12
)

regional_consistency$summary
regional_consistency$variable_summary

checkmate::assert_true(
  regional_consistency$summary$validation_passed,
  .var.name = "regional consistency validation"
)
