#' Crop NetCDF rasters to a polygon extent
#'
#' Reads time-indexed NetCDF files and crops their rasters to the rectangular
#' extent of a supplied polygon set.
#'
#' @param data_path Character scalar giving the directory that contains the
#'   NetCDF files.
#' @param polygons An `sf` or `SpatVector` object containing one or more
#'   polygon geometries. Its CRS must equal the CRS of every selected raster.
#' @param file_prefixes Named character vector that associates each output
#'   name with the literal file prefix used to select its NetCDF files. For
#'   example, `c(pr = "pr_mly_", ETo = "ETo_mly_")` selects monthly BR-DWGD
#'   files, whereas `c(pr = "pr_")` can select daily files in a directory
#'   containing only daily precipitation NetCDFs.
#'
#' @return A named list of `SpatRaster` objects, one for each element of
#'   `file_prefixes`. Each raster contains the complete time series selected
#'   by that prefix, cropped to the combined extent of `polygons`.
#'
#' @details
#' File selection is literal: the base name must start with the corresponding
#' value in `file_prefixes` and end in `.nc`. Temporal coordinates are read
#' from the NetCDF time dimension; they are not reconstructed from file names.
#'
#' The temporal resolution is not restricted. Daily, monthly, subdaily and
#' irregular time series are accepted. Each raster must expose a time
#' coordinate through [terra::time()]. Files are ordered by their first time
#' value, and the combined coordinate must be unique and strictly increasing.
#'
#' The operation is a rectangular crop, not a spatial mask. With
#' `snap = "out"`, the resulting extent is aligned outwards to the source grid,
#' retaining every source cell touched by the polygon extent. Cells inside the
#' rectangle but outside the polygons therefore remain available for later
#' spatial operations.
#'
#' This function neither transforms polygons nor resamples rasters. A CRS
#' mismatch is treated as an input error.
#'
#' @examples
#' \dontrun{
#' reference_crs <- terra::rast("path/to/pr_mly_2020.nc") |>
#'   terra::crs()
#'
#' municipalities <- load_ibge_municipalities(
#'   states = "RS",
#'   target_crs = reference_crs
#' )
#'
#' monthly_rasters <- crop_netcdfs(
#'   data_path = "path/to/monthly",
#'   polygons = municipalities,
#'   file_prefixes = c(
#'     pr = "pr_mly_",
#'     ETo = "ETo_mly_"
#'   )
#' )
#' }
#'
#' @importFrom checkmate assert_character assert_directory_exists assert_true
#' @importFrom purrr map set_names
#' @importFrom tictoc tic toc
#'
#' @export
crop_netcdfs <- function(data_path, polygons, file_prefixes) {
  checkmate::assert_directory_exists(data_path, access = "r")
  checkmate::assert_character(
    file_prefixes,
    min.len = 1,
    any.missing = FALSE,
    unique = TRUE,
    names = "unique"
  )
  checkmate::assert_character(
    names(file_prefixes),
    min.len = 1,
    min.chars = 1,
    any.missing = FALSE,
    unique = TRUE,
    .var.name = "names(file_prefixes)"
  )

  polygon_vector <- validate_crop_polygons(polygons)
  output_names <- names(file_prefixes)

  purrr::map(
    file_prefixes,
    function(file_prefix) {
      cli::cli_alert_info(
        "Cropping NetCDF files with prefix {.val {file_prefix}}."
      )

      crop_netcdfs_by_prefix(
        file_prefix = file_prefix,
        data_path = data_path,
        polygons = polygon_vector
      )
    }
  ) |>
    purrr::set_names(output_names)
}

#' Validate polygons used to crop rasters
#'
#' @param polygons An `sf` or `SpatVector` object.
#'
#' @return A non-empty polygon `SpatVector` with a defined CRS.
#'
#' @noRd
validate_crop_polygons <- function(polygons) {
  checkmate::assert_true(
    inherits(polygons, "sf") || inherits(polygons, "SpatVector"),
    .var.name = "polygons (an sf or SpatVector object)"
  )

  polygon_vector <- if (inherits(polygons, "SpatVector")) {
    polygons
  } else {
    terra::vect(polygons)
  }

  checkmate::assert_true(
    nrow(polygon_vector) > 0,
    .var.name = "polygons (at least one feature)"
  )
  checkmate::assert_true(
    terra::is.polygons(polygon_vector),
    .var.name = "polygons (polygon geometries only)"
  )
  checkmate::assert_string(
    terra::crs(polygon_vector),
    min.chars = 1,
    .var.name = "polygons CRS"
  )

  polygon_vector
}

#' Crop one NetCDF to a polygon extent
#'
#' @param netcdf_path Character scalar giving a NetCDF path.
#' @param polygons A validated polygon `SpatVector`.
#'
#' @return A cropped `SpatRaster` that retains its original time coordinate.
#'
#' @noRd
crop_netcdf <- function(netcdf_path, polygons) {
  checkmate::assert_file_exists(
    netcdf_path,
    access = "r",
    extension = "nc"
  )

  netcdf_name <- fs::path_file(netcdf_path)
  cli::cli_alert_info("Cropping {.file {netcdf_name}}.")

  tictoc::tic(msg = netcdf_name)
  timer_running <- TRUE
  on.exit(
    if (timer_running) {
      tictoc::toc(quiet = TRUE)
    },
    add = TRUE
  )

  raster <- terra::rast(netcdf_path)
  checkmate::assert_true(
    terra::has.time(raster),
    .var.name = paste0("time dimension in ", netcdf_name)
  )
  time_values <- terra::time(raster)
  checkmate::assert_true(
    terra::same.crs(raster, polygons),
    .var.name = paste0("matching raster and polygon CRS for ", netcdf_name)
  )

  cropped_raster <- terra::crop(
    raster,
    polygons,
    snap = "out"
  )
  terra::time(cropped_raster) <- time_values
  names(cropped_raster) <- as.character(time_values)

  timing <- tictoc::toc(quiet = TRUE)
  timer_running <- FALSE
  elapsed_seconds <- timing$toc - timing$tic
  cli::cli_alert_success(
    "Cropped {.file {netcdf_name}} in {round(elapsed_seconds, 1)} s."
  )

  cropped_raster
}

#' Crop all NetCDF files matching one prefix
#'
#' @param file_prefix Character scalar containing a literal file prefix.
#' @param data_path Character scalar giving the NetCDF directory.
#' @param polygons A validated polygon `SpatVector`.
#'
#' @return A time-ordered `SpatRaster` containing all selected layers.
#'
#' @noRd
crop_netcdfs_by_prefix <- function(file_prefix, data_path, polygons) {
  checkmate::assert_string(file_prefix, min.chars = 1)

  netcdf_paths <- fs::dir_ls(
    data_path,
    glob = "*.nc",
    type = "file"
  ) |>
    purrr::keep(
      function(path) {
        stringr::str_starts(fs::path_file(path), file_prefix)
      }
    )

  checkmate::assert_character(
    netcdf_paths,
    min.len = 1,
    .var.name = paste0(
      "NetCDF files matching '",
      file_prefix,
      "*.nc' in data_path"
    )
  )

  cropped_rasters <- purrr::map(
    netcdf_paths,
    crop_netcdf,
    polygons = polygons
  )
  raster_times <- purrr::map(cropped_rasters, terra::time)
  time_classes <- purrr::map_chr(
    raster_times,
    \(time_values) paste(class(time_values), collapse = "/")
  )
  checkmate::assert_true(
    length(unique(time_classes)) == 1,
    .var.name = paste0(
      "consistent time classes for files matching ",
      file_prefix
    )
  )

  first_times <- purrr::map_dbl(
    raster_times,
    \(time_values) as.numeric(time_values)[[1]]
  )
  file_order <- order(first_times)
  cropped_rasters <- cropped_rasters[file_order]
  raster_times <- raster_times[file_order]

  combined_time <- do.call(c, raster_times)
  numeric_time <- as.numeric(combined_time)
  checkmate::assert_numeric(
    numeric_time,
    any.missing = FALSE,
    finite = TRUE,
    unique = TRUE,
    .var.name = paste0(
      "combined time values for files matching ",
      file_prefix
    )
  )
  checkmate::assert_true(
    length(numeric_time) == 1 || all(diff(numeric_time) > 0),
    .var.name = paste0(
      "strictly increasing combined time values for files matching ",
      file_prefix
    )
  )

  combined_raster <- terra::rast(cropped_rasters)
  terra::time(combined_raster) <- combined_time
  names(combined_raster) <- as.character(combined_time)

  combined_raster
}
