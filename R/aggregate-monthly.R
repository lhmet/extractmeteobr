# 00. GET MONTHLY CLIMATE NETCDFS ----
# One-time preprocessing step: daily BR-DWGD rasters -> monthly rasters.

#' Aggregate BR-DWGD daily NetCDF files into monthly NetCDF files
#'
#' Finds the daily NetCDF files for each requested variable, aggregates their
#' layers by calendar month, and writes one monthly NetCDF beside each input
#' file, inside a `monthly/` subdirectory.
#'
#' @param variables Character vector containing the variable prefixes to
#'   process, such as `c("pr", "ETo")`.
#' @param overwrite Logical scalar. If `FALSE`, an existing output file is
#'   reused. If `TRUE`, it is recomputed.
#' @param data_path Character scalar giving the directory that contains the
#'   daily BR-DWGD NetCDF files. There is no default; the caller must supply
#'   the directory explicitly.
#' @param aggregation_functions Named list containing one aggregation-function
#'   name for each entry in `variables`. The defaults use `"sum"` to calculate
#'   monthly totals for precipitation (`pr`) and reference evapotranspiration
#'   (`ETo`).
#' @return Character vector containing the monthly NetCDF paths, one for each
#'   daily input file.
#'
#' @details
#' File matching is literal: a file belongs to a variable only when its base
#' name starts with `<variable>_`. Files already prefixed with
#' `<variable>_mly_` are excluded.
#'
#' Monthly sums retain the spatial `NA` pattern of the daily BR-DWGD grid, so
#' cells outside the valid domain are not converted to zeros.
#'
#' `overwrite = FALSE` only checks whether the output exists; it does not check
#' which aggregation function created that file. Set `overwrite = TRUE` after
#' changing `aggregation_functions`.
#'
#' The elapsed processing time is reported separately for each input file. It
#' covers raster reading, monthly aggregation, and NetCDF writing. Files reused
#' with `overwrite = FALSE` are not timed because no processing is performed.
#'
#' @references
#' [BR-DWGD author page](https://sites.google.com/site/alexandrecandidoxavierufes/brazilian-daily-weather-gridded-data), including version information and downloads:
#' [ZIP archives](https://drive.google.com/drive/folders/11-qnvwojirAtaQxSE03N0_SUrbcsz44N) and [NetCDF files](https://www.dropbox.com/scl/fo/t225fii1ir4o5ozga0o3u/ALZsq0F4zeCykN4GgoD8D6s?dl=0&rlkey=93nkonzxn08c4wioztkjq0x52&st=oq6g1i0m).
#'
#' Xavier, A. C., Scanlon, B. R., King, C. W., and Alves, A. I. (2022).
#' New improved Brazilian daily weather gridded data (1961–2020).
#' International Journal of Climatology, 42(16), 8390–8404.
#' DOI: [10.1002/joc.7731](https://doi.org/10.1002/joc.7731).
#'
#' @examples
#' \dontrun{
#' monthly_files <- aggregate_daily_netcdfs_by_month(
#'   variables = c("pr", "ETo"),
#'   data_path = "path/to/br-dwgd/daily",
#'   aggregation_functions = list(pr = "sum", ETo = "sum")
#' )
#' }
#'
#' @importFrom checkmate assert_character assert_directory_exists assert_flag
#' @importFrom checkmate assert_list assert_names
#' @importFrom fs dir_ls path_file
#' @importFrom purrr keep map map_chr
#' @importFrom stringr str_starts
#'
#' @export
aggregate_daily_netcdfs_by_month <- function(
    data_path,
    variables = c("pr", "ETo"),
    overwrite = FALSE,
    aggregation_functions = list(pr = "sum", ETo = "sum")
) {
  checkmate::assert_character(
    variables,
    min.len = 1,
    any.missing = FALSE,
    unique = TRUE
  )
  checkmate::assert_flag(overwrite)
  checkmate::assert_directory_exists(data_path)
  checkmate::assert_list(
    aggregation_functions,
    types = "character",
    names = "unique"
  )
  checkmate::assert_names(
    names(aggregation_functions),
    must.include = variables,
    type = "unique"
  )
  daily_nc_files <- fs::dir_ls(
    data_path,
    glob = "*.nc",
    type = "file"
  )

  monthly_files <- purrr::map(
    variables,
    function(variable) {
      variable_prefix <- paste0(variable, "_")
      monthly_prefix <- paste0(variable, "_mly_")

      variable_files <- purrr::keep(
        daily_nc_files,
        function(file) {
          file_name <- fs::path_file(file)
          stringr::str_starts(file_name, variable_prefix) &&
            !stringr::str_starts(file_name, monthly_prefix)
        }
      )

      checkmate::assert_character(
        variable_files,
        min.len = 1,
        .var.name = paste0(
          "daily NetCDF files for variable '",
          variable,
          "' in data_path"
        )
      )

      purrr::map_chr(
        variable_files,
        aggregate_daily_netcdf_by_month,
        aggregation_function = aggregation_functions[[variable]],
        overwrite = overwrite
      )
    }
  )

  unname(unlist(monthly_files, use.names = FALSE))
}

#' Infer a BR-DWGD variable name from a NetCDF file name
#'
#' @param data_file Character scalar giving a BR-DWGD NetCDF path.
#'
#' @return Character scalar containing the text before the first underscore in
#'   the base file name.
#'
#' @examples
#' infer_br_dwgd_variable("/data/pr_20200101_20201231_BR-DWGD.nc")
#'
#' @importFrom checkmate assert_string
#' @importFrom fs path_file
#' @importFrom stringr str_split_1
#'
#' @noRd
infer_br_dwgd_variable <- function(data_file) {
  checkmate::assert_string(data_file, min.chars = 1)

  file_parts <- fs::path_file(data_file) |>
    stringr::str_split_1(pattern = "_")

  file_parts[[1]]
}

#' Build the monthly NetCDF output path
#'
#' @param data_file Character scalar giving the daily NetCDF path.
#'
#' @return Character scalar pointing to the `monthly/` subdirectory, with
#'   `_mly` inserted after the variable prefix in the base file name.
#'
#' @examples
#' \dontrun{
#' make_monthly_nc_path(
#'   "/data/pr_20200101_20201231_BR-DWGD.nc"
#' )
#' }
#'
#' @importFrom checkmate assert_string
#' @importFrom fs dir_create dir_exists path path_dir path_file
#' @importFrom stringr str_starts
#'
#' @noRd
make_monthly_nc_path <- function(data_file) {
  checkmate::assert_string(data_file, min.chars = 1)

  input_name <- fs::path_file(data_file)
  checkmate::assert_string(
    input_name,
    pattern = "^[^_]+_.+\\.nc$",
    .var.name = "BR-DWGD NetCDF file name"
  )

  variable <- infer_br_dwgd_variable(data_file)
  input_prefix <- paste0(variable, "_")
  output_dir <- fs::path(fs::path_dir(data_file), "monthly")
  if (!fs::dir_exists(output_dir)) {
    fs::dir_create(output_dir)
  }

  output_name <- paste0(
    variable,
    "_mly_",
    substring(input_name, nchar(input_prefix) + 1L)
  )

  fs::path(output_dir, output_name)
}

#' Aggregate a daily climate NetCDF file into monthly values
#'
#' Reads one daily BR-DWGD NetCDF, aggregates its layers by calendar month,
#' and writes the result to a NetCDF file inside a `monthly/` subdirectory.
#'
#' @param data_file Character scalar giving a daily NetCDF file readable by
#'   [terra::rast()]. Its variable name is inferred from the file name with
#'   an internal file-name parser.
#' @param aggregation_function Character scalar naming a summary function
#'   supported by [terra::tapp()], such as `"sum"` or `"mean"`.
#' @param overwrite Logical scalar. If `FALSE` and the output already exists,
#'   its path is returned without recomputation.
#' @return Character scalar giving the monthly NetCDF path.
#'
#' @details
#' The raster time dimension must contain one non-missing and unique date per
#' layer, with consecutive one-day intervals. Dates are floored to the first
#' day of their calendar month and used as the grouping index in
#' [terra::tapp()].
#'
#' [terra::tapp()] applies the function named by `aggregation_function` with
#' `na.rm = TRUE`. BR-DWGD fields are assumed to be spatially and temporally
#' continuous over the processing domain; therefore, no coverage threshold is
#' applied. When `aggregation_function = "sum"`, the spatial `NA` pattern from
#' the first daily layer is reapplied with [terra::mask()]. This prevents cells
#' outside the valid BR-DWGD domain from becoming observed zeros because
#' `sum(..., na.rm = TRUE)` returns zero when all inputs are `NA`.
#'
#' After a successful write, the elapsed wall-clock time is reported for the
#' input file. The measurement includes reading, aggregation, and NetCDF
#' writing. The native `terra` progress bar is temporarily disabled to avoid
#' graphical-device redraw warnings in IDEs. The previous `terra` progress
#' setting is restored when the function exits.
#'
#' @examples
#' \dontrun{
#' monthly_pr <- aggregate_daily_netcdf_by_month(
#'   data_file = "path/to/pr_20200101_20201231_BR-DWGD.nc",
#'   aggregation_function = "sum",
#'   overwrite = TRUE
#' )
#' }
#'
#' @importFrom checkmate assert_date assert_file_exists assert_flag
#' @importFrom checkmate assert_string assert_true
#' @importFrom cli cli_alert_info cli_alert_success
#' @importFrom fs file_exists
#' @importFrom lubridate as_date floor_date
#' @importFrom terra mask nlyr rast tapp terraOptions time writeCDF
#'
#' @seealso [aggregate_daily_netcdfs_by_month()]
#'
#' @export
aggregate_daily_netcdf_by_month <- function(
    data_file,
    aggregation_function = "sum",
    overwrite = TRUE
) {
  checkmate::assert_file_exists(
    data_file,
    access = "r",
    extension = "nc"
  )
  checkmate::assert_string(aggregation_function, min.chars = 1)
  checkmate::assert_flag(overwrite)

  output_file <- make_monthly_nc_path(data_file)
  if (!overwrite && fs::file_exists(output_file)) {
    cli::cli_alert_info("Reusing existing file: {.file {output_file}}")
    return(output_file)
  }

  processing_started_at <- Sys.time()


  terra::terraOptions(progress = 10)


  daily_raster <- terra::rast(data_file)
  daily_dates <- daily_raster |>
    terra::time() |>
    lubridate::as_date()

  checkmate::assert_date(
    daily_dates,
    len = terra::nlyr(daily_raster),
    any.missing = FALSE,
    unique = TRUE
  )
  checkmate::assert_true(
    length(daily_dates) == 1 || all(diff(daily_dates) == 1),
    .var.name = "daily_dates with consecutive one-day intervals"
  )

  month_index <- lubridate::floor_date(daily_dates, unit = "month")
  months <- unique(month_index)

  cli::cli_alert_info(
    "Aggregating daily file {.file {fs::path_file(data_file)}} by month."
  )

  monthly_raster <- terra::tapp(
    x = daily_raster,
    index = month_index,
    fun = aggregation_function,
    na.rm = TRUE
  )

  if (aggregation_function == "sum") {
    monthly_raster <- terra::mask(
      monthly_raster,
      daily_raster[[1]]
    )
  }

  terra::time(monthly_raster) <- months
  names(monthly_raster) <- as.character(months)

  variable <- infer_br_dwgd_variable(data_file)
  terra::writeCDF(
    monthly_raster,
    filename = output_file,
    varname = variable,
    overwrite = overwrite,
    compression = 9
  )

  checkmate::assert_file_exists(output_file)

  elapsed_seconds <- as.numeric(
    difftime(Sys.time(), processing_started_at, units = "secs")
  )
  elapsed_time <- sprintf("%.1f s", elapsed_seconds)
  cli::cli_alert_success(
    paste0(
      "Processed {.file {fs::path_file(data_file)}} in {elapsed_time}. ",
      "Saved as {.file {output_file}}"
    )
  )

  output_file
}
