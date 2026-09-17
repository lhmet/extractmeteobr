# make_polygon_cell_weights() uses data.table's `:=` on a data.table built
# from terra::extract() output. data.table requires calling packages to
# declare awareness of its non-standard evaluation instead of fully importing
# the namespace; see vignette("datatable-importing", package = "data.table").
.datatable.aware <- TRUE

#' Calculate area-weighted raster means over polygons
#'
#' Calculates area-weighted means for a named list of rasters over a common
#' set of polygons. Exact polygon-cell intersection weights are calculated
#' once from the first raster and reused for every variable and layer.
#'
#' @param rasters Non-empty named list of SpatRaster objects. List names become
#'   variable names in the output. All rasters must use the same spatial grid.
#' @param polygons An sf object containing the polygons.
#' @param id_col Character scalar naming the unique polygon identifier.
#'
#' @return A tibble with one row per polygon and date It contains polygon_id,
#'   date, and one numeric column for each element of rasters.
#'
#' @details
#' For raster value x observed in cell i, polygon j, and date t, the estimator
#' is
#'
#' \deqn{
#' \bar{x}_{jt} =
#' \frac{\sum_i I_{it} x_{it} f_{ij} A_i}
#'      {\sum_i I_{it} f_{ij} A_i},
#' }
#'
#' where f is the fraction of the raster cell contained in the polygon, A is
#' the physical cell area, and I is one for available values and zero for
#' missing values. Consequently, observed zeros contribute to the estimate,
#' whereas NA values are excluded from both numerator and denominator.
#'
#' The function assumes that all rasters share the grid of the first raster.
#' It preserves the temporal class stored by terra and does not require a
#' regular temporal interval.
#'
#' @examples
#' \dontrun{
#' municipal_means <- extract_area_weighted_mean(
#'   rasters = filled_monthly_rasters,
#'   polygons = municipalities
#' )
#' }
#'
#' @importFrom checkmate assert_character assert_class assert_list
#' @importFrom checkmate assert_names assert_true
#' @importFrom purrr map2 map_lgl
#' @importFrom tibble as_tibble
#'
#' @export
extract_area_weighted_mean <- function(
    rasters,
    polygons,
    id_col = "polygon_id"
) {
  checkmate::assert_list(
    rasters,
    min.len = 1,
    names = "unique"
  )
  checkmate::assert_character(
    id_col,
    len = 1,
    any.missing = FALSE
  )
  checkmate::assert_true(
    all(purrr::map_lgl(rasters, inherits, what = "SpatRaster")),
    .var.name = "all elements of rasters are SpatRaster objects"
  )
  checkmate::assert_character(
    names(rasters),
    len = length(rasters),
    min.chars = 1,
    any.missing = FALSE,
    unique = TRUE,
    .var.name = "names(rasters)"
  )
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_names(
    names(polygons),
    must.include = id_col
  )
  checkmate::assert_true(
    !anyNA(polygons[[id_col]]) &&
      !anyDuplicated(polygons[[id_col]]),
    .var.name = id_col
  )

  polygon_ids <- as.character(polygons[[id_col]])
  cell_weights <- make_polygon_cell_weights(
    raster = rasters[[1]],
    polygons = polygons,
    polygon_ids = polygon_ids
  )

  results <- purrr::map2(
    rasters,
    names(rasters),
    \(raster, variable) {
      calculate_area_weighted_mean(
        raster = raster,
        cell_weights = cell_weights,
        polygon_ids = polygon_ids,
        variable = variable
      )
    }
  ) |>
    data.table::rbindlist()

  polys_monthly_means <- data.table::dcast(
    results,
    polygon_id + date ~ variable,
    value.var = "value"
  ) |>
    tibble::as_tibble()


  polys_monthly_means


}

#' Calculate polygon-cell intersection weights
#'
#' @param raster A SpatRaster defining the reference grid.
#' @param polygons An sf object containing the polygons.
#' @param polygon_ids Character vector containing the polygon identifiers.
#'
#' @return A data.table with polygon rows, cell numbers, and intersection areas
#'   in square metres.
#'
#' @keywords internal
#' @noRd
make_polygon_cell_weights <- function(
    raster,
    polygons,
    polygon_ids
) {
  reference_raster <- raster[[1]]

  intersections <- terra::extract(
    reference_raster,
    terra::vect(polygons),
    cells = TRUE,
    exact = TRUE
  ) |>
    data.table::as.data.table()

  checkmate::assert_true(
    nrow(intersections) > 0,
    .var.name = "polygon-cell intersections"
  )
  checkmate::assert_names(
    names(intersections),
    must.include = c("ID", "cell", "fraction")
  )
  checkmate::assert_true(
    all(seq_along(polygon_ids) %in% intersections$ID),
    .var.name = "all polygons intersect the raster"
  )

  cells <- funique::funique(intersections$cell)
  cell_areas <- terra::extract(
    terra::cellSize(reference_raster, unit = "m"),
    cells,
    raw = TRUE
  )[, 1]

  intersections[
    ,
    area_weight := fraction * cell_areas[match(cell, cells)]
  ]
  intersections[
    ,
    polygon_id := polygon_ids[ID]
  ]

  cell_weights <- intersections[
    ,
    .(ID, polygon_id, cell, area_weight)
  ]
  checkmate::assert_true(
    all(is.finite(cell_weights$area_weight)) &&
      all(cell_weights$area_weight > 0),
    .var.name = "positive finite polygon-cell area weights"
  )

  data.table::setorder(cell_weights, ID, cell)
  cell_weights[]
}

#' Calculate area-weighted means for one raster
#'
#' @param raster A SpatRaster.
#' @param cell_weights Polygon-cell weights from make_polygon_cell_weights().
#' @param polygon_ids Character vector containing the polygon identifiers.
#' @param variable Character scalar identifying the raster variable.
#'
#' @return A data.table in long format.
#'
#' @keywords internal
#' @noRd
calculate_area_weighted_mean <- function(
    raster,
    cell_weights,
    polygon_ids,
    variable
) {
  time_values <- terra::time(raster)
  checkmate::assert_true(
    length(time_values) == terra::nlyr(raster) &&
      !anyNA(time_values),
    .var.name = paste0("complete time coordinate for ", variable)
  )

  cells <- sort(funique::funique(cell_weights$cell))
  weight_matrix <- Matrix::sparseMatrix(
    i = cell_weights$ID,
    j = match(cell_weights$cell, cells),
    x = cell_weights$area_weight,
    dims = c(length(polygon_ids), length(cells))
  )

  raster_values <- terra::extract(
    raster,
    cells,
    raw = TRUE
  )
  if (!is.matrix(raster_values)) {
    raster_values <- as.matrix(raster_values)
  }

  valid <- !is.na(raster_values)
  raster_values[!valid] <- 0

  numerator <- as.matrix(weight_matrix %*% raster_values)
  denominator <- as.matrix(weight_matrix %*% valid)
  weighted_mean <- numerator / denominator
  weighted_mean[denominator == 0] <- NA_real_

  data.table::data.table(
    polygon_id = rep(polygon_ids, times = terra::nlyr(raster)),
    date = rep(time_values, each = length(polygon_ids)),
    variable = variable,
    value = as.vector(weighted_mean)
  )
}
