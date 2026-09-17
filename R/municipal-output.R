#' Join municipal attributes and write area-weighted means
#'
#' Adds municipal attributes to the generic polygon means and writes the
#' result to an `.fst` file with the state identifier in its name.
#'
#' @param means Tibble returned by [extract_area_weighted_mean()].
#' @param polygons An sf object containing municipal attributes.
#' @param id_col Character scalar naming the polygon identifier.
#' @param state_col Character scalar naming the state identifier.
#' @param region Optional lowercase Brazilian region name used as the output
#'   suffix instead of concatenated state codes.
#' @param output_dir Character scalar giving the output directory. There is no
#'   default; the caller must supply the directory explicitly.
#' @param file_stem Character scalar used before the state suffix.
#' @return The joined tibble.
#' @export
join_and_write_municipal_means <- function(
    means,
    polygons,
    output_dir,
    id_col = "polygon_id",
    state_col = "state",
    region = NULL,
    file_stem = "area-weighted-means"
) {
  means <- tibble::as_tibble(means)
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_names(
    names(polygons),
    must.include = c(id_col, state_col)
  )
  checkmate::assert_names(
    names(means),
    must.include = c("polygon_id", "date")
  )

  polygon_attributes <- sf::st_drop_geometry(polygons)
  names(polygon_attributes)[names(polygon_attributes) == id_col] <- "polygon_id"
  polygon_attributes$polygon_id <- as.character(polygon_attributes$polygon_id)

  joined_means <- means |>
    dplyr::left_join(polygon_attributes, by = "polygon_id") |>
    dplyr::relocate(
      polygon_id,
      dplyr::all_of(setdiff(names(polygon_attributes), "polygon_id")),
      date
    ) |>
    tibble::as_tibble()

  state_ids <- unique(as.character(polygons[[state_col]])) |>
    sort() |>
    tolower()
  checkmate::assert_character(state_ids, min.len = 1, any.missing = FALSE)
  checkmate::assert_true(all(grepl("^[[:alnum:]]+$", state_ids)))
  checkmate::assert_character(
    file_stem,
    len = 1,
    min.chars = 1,
    pattern = "^[[:alnum:]][[:alnum:]-]*$"
  )

  if (is.null(region)) {
    area_suffix <- paste(state_ids, collapse = "-")
  } else {
    checkmate::assert_choice(
      region,
      choices = c("norte", "nordeste", "centro-oeste", "sudeste", "sul")
    )
    area_suffix <- region
  }

  output_path <- fs::path(
    output_dir,
    paste0(file_stem, "-", area_suffix, ".fst")
  )
  fs::dir_create(output_dir)
  fst::write_fst(joined_means, output_path)
  cli::cli_alert_success("Municipal means written to {.file {output_path}}.")

  joined_means
}
