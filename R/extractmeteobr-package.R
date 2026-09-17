#' extractmeteobr: area-weighted municipal meteorological time series
#'
#' Converts gridded BR-DWGD meteorological NetCDF rasters into area-weighted
#' time series for Brazilian municipalities and states.
#'
#' @keywords internal
"_PACKAGE"

# Column names referenced by non-standard evaluation (data.table `[.data.table`
# expressions and dplyr pipelines) are not visible to R CMD check's static
# analysis. They are declared here, as recommended by
# vignette("importing", package = "data.table"), rather than silenced ad hoc
# in each function.
utils::globalVariables(c(
  ".",
  ":=",
  "ID",
  "area",
  "area_weight",
  "cell",
  "fraction",
  "municipality",
  "polygon_id",
  "state"
))
