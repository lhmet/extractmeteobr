#' Create inverse-distance weights for a focal window
#'
#' @param window_size Positive odd integer defining the number of rows and
#'   columns in the focal window. Values must be at least 3.
#' @param power Positive numeric scalar defining the inverse-distance power.
#'
#' @return A numeric square matrix with a zero weight at its centre.
#'
#' @keywords internal
#' @noRd
make_idw_weights <- function(
    window_size = 5L,
    power = 2
) {
  checkmate::assert_int(
    window_size,
    lower = 3
  )
  checkmate::assert_number(
    power,
    lower = .Machine$double.eps,
    finite = TRUE
  )
  checkmate::assert_true(
    window_size %% 2 == 1,
    .var.name = "window_size must be odd"
  )

  radius <- (window_size - 1) / 2
  coordinates <- seq.int(-radius, radius)
  distances <- outer(
    coordinates,
    coordinates,
    \(x, y) sqrt(x^2 + y^2)
  )

  weights <- distances^(-power)
  weights[radius + 1, radius + 1] <- 0
  weights
}

#' Fill missing raster cells intersecting polygons
#'
#' Checks the first layer of the first raster for NA cells intersecting the
#' supplied polygons. If at least one such cell exists, all rasters are
#' interpolated; otherwise, the original list is returned unchanged.
#'
#' @param rasters Named list of SpatRaster objects.
#' @param polygons An sf object or SpatVector containing the polygons.
#' @param window_size Positive odd integer defining the focal window size.
#' @param power Positive numeric scalar defining the inverse-distance power.
#'
#' @return A named list of SpatRaster objects in the same order as rasters.
#'   Rasters requiring no interpolation are returned unchanged.
#'
#' @details
#' The test uses only the first layer of the first raster and therefore assumes
#' that all rasters share the same spatial NA mask. When interpolation is
#' needed, terra::focal() processes all layers but modifies only missing cells.
#'
#' @examples
#' \dontrun{
#' filled_rasters <- fill_missing_raster_cells(
#'   rasters = monthly_rasters,
#'   polygons = municipalities
#' )
#' }
#'
#' @importFrom checkmate assert_class assert_list assert_true
#' @importFrom purrr map map_lgl
#' @importFrom terra cells extract focal same.crs vect
#'
#' @export
fill_missing_raster_cells <- function(
    rasters,
    polygons,
    window_size = 5L,
    power = 2
) {
  checkmate::assert_list(
    rasters,
    min.len = 1,
    names = "unique"
  )
  checkmate::assert_true(
    all(purrr::map_lgl(rasters, inherits, what = "SpatRaster")),
    .var.name = "all elements of rasters are SpatRaster objects"
  )

  if (inherits(polygons, "sf")) {
    polygons <- terra::vect(polygons)
  }
  checkmate::assert_class(polygons, "SpatVector")

  reference_raster <- rasters[[1]][[1]]
  checkmate::assert_true(
    terra::same.crs(reference_raster, polygons),
    .var.name = "shared CRS for rasters and polygons"
  )

  intersecting_cells <- terra::cells(
    reference_raster,
    polygons,
    touches = TRUE
  )[, "cell"] |>
    funique::funique()
  checkmate::assert_true(
    length(intersecting_cells) > 0,
    .var.name = "raster cells intersecting polygons"
  )

  intersecting_values <- terra::extract(
    reference_raster,
    intersecting_cells,
    raw = TRUE
  )[, 1]
  n_na_cells <- sum(is.na(intersecting_values))

  if (n_na_cells == 0) {
    cli::cli_alert_success(
      paste0(
        "0 of {length(intersecting_cells)} cells in the polygon domain ",
        "are NA; interpolation skipped."
      )
    )
    return(rasters)
  }

  cli::cli_alert_info(
    paste0(
      "{n_na_cells} of {length(intersecting_cells)} cells in the polygon ",
      "domain are NA; interpolating rasters."
    )
  )

  weights <- make_idw_weights(
    window_size = window_size,
    power = power
  )

  purrr::map(
    rasters,
    \(raster) {
      terra::focal(
        raster,
        w = weights,
        fun = "mean",
        na.policy = "only",
        na.rm = TRUE
      )
    }
  )
}
