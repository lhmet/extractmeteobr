#' Run the complete meteorological polygon-extraction pipeline
#'
#' Executes regional polygon loading, raster cropping, conditional missing-cell
#' filling, area-weighted extraction, and municipal output steps in sequence.
#'
#' The functions used by this orchestrator must already be available in the
#' current R session. This keeps the orchestration layer independent from the
#' way the project functions are loaded.
#'
#' @param states Character vector of lowercase two-letter Brazilian state codes
#'   or one lowercase region name: `"norte"`, `"nordeste"`,
#'   `"centro-oeste"`, `"sudeste"`, or `"sul"`.
#' @param monthly_data_path Directory containing already aggregated monthly
#'   BR-DWGD NetCDF files. There is no default; the caller must supply the
#'   directory explicitly.
#' @param municipality_data_path Path to the IBGE municipal shapefile. There
#'   is no default; the caller must supply the file path explicitly.
#' @param output_dir Directory for the municipal `.fst` output. There is no
#'   default; the caller must supply the directory explicitly.
#' @param variables Character vector of raster variables.
#' @param target_crs CRS used for the polygons and rasters. If `NULL`, it is
#'   inferred from the first monthly NetCDF created or reused.
#' @param file_stem Output file stem before the state suffix.
#' @param return_intermediate Logical scalar. If `TRUE`, returns the outputs of
#'   all pipeline stages. If `FALSE`, returns only the final municipal data.
#'
#' @return If `return_intermediate = TRUE`, a named list containing the outputs
#'   relevant pipeline outputs: `monthly_files`, `municipalities`,
#'   `filled_monthly_rasters`, and `municipal_monthly_means`. Otherwise,
#'   returns only the final municipal tibble. Superseded intermediate objects
#'   are not included in the returned list.
#'
#' @details
#' Project inputs use BR-DWGD version 3.2.4 daily precipitation and reference
#' evapotranspiration for 1961–2025. Prepare the monthly files with
#' [aggregate_daily_netcdfs_by_month()] before calling this pipeline.
#' The pipeline reads caller-supplied monthly files; it does not download
#' data or perform daily-to-monthly aggregation.
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
#' @export
run_meteo_pipeline <- function(
    states,
    monthly_data_path,
    municipality_data_path,
    output_dir,
    variables = c("pr", "ETo"),
    target_crs = NULL,
    file_stem = "municipal-monthly-meteorology",
    return_intermediate = TRUE
) {
  brazilian_regions <- c(
    "norte",
    "nordeste",
    "centro-oeste",
    "sudeste",
    "sul"
  )
  region <- if (length(states) == 1L && states %in% brazilian_regions) {
    states
  } else {
    NULL
  }
  states <- resolve_brazilian_states(states)
  checkmate::assert_character(variables, min.len = 1, unique = TRUE)
  checkmate::assert_flag(return_intermediate)
  checkmate::assert_directory_exists(monthly_data_path, access = "r")
  monthly_files <- fs::dir_ls(
    monthly_data_path,
    glob = "*.nc",
    type = "file"
  )
  checkmate::assert_character(monthly_files, min.len = 1)

  first_monthly_file <- monthly_files[
    stringr::str_starts(fs::path_file(monthly_files), "pr_mly_")
  ][[1]]
  if (is.null(target_crs)) {
    target_crs <- terra::crs(terra::rast(first_monthly_file))
  }

  municipalities <- load_ibge_municipalities(
    states = states,
    target_crs = target_crs,
    data_path = municipality_data_path,
    remove_lagoons = FALSE
  )

  monthly_rasters <- crop_netcdfs(
    data_path = monthly_data_path,
    polygons = municipalities,
    file_prefixes = purrr::set_names(
      paste0(variables, "_mly_"),
      variables
    )
  )

  filled_monthly_rasters <- fill_missing_raster_cells(
    rasters = monthly_rasters,
    polygons = municipalities,
    window_size = 5L,
    power = 2
  )

  area_weighted_means <- extract_area_weighted_mean(
    rasters = filled_monthly_rasters,
    polygons = municipalities,
    id_col = "polygon_id"
  )

  municipal_monthly_means <- join_and_write_municipal_means(
    means = area_weighted_means,
    polygons = municipalities,
    id_col = "polygon_id",
    state_col = "state",
    region = region,
    output_dir = output_dir,
    file_stem = file_stem
  )

  if (!return_intermediate) {
    return(municipal_monthly_means)
  }

  list(
    monthly_files = monthly_files,
    municipalities = municipalities,
    filled_monthly_rasters = filled_monthly_rasters,
    municipal_monthly_means = municipal_monthly_means
  )
}
