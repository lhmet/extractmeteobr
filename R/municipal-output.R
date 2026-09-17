#' Join municipal attributes and write area-weighted means
#'
#' Adds municipal attributes to the generic polygon means and writes the
#' result to an `.fst` file. Selected polygon attributes are retained before
#' joining, without requiring municipal-specific attributes.
#'
#' @param means Tibble returned by [extract_area_weighted_mean()], containing
#'   non-missing, non-blank character `polygon_id` values present in `polygons`.
#'   An identifier may occur on multiple dates.
#' @param polygons An `sf` object containing polygon attributes.
#' @param id_col Character scalar naming the polygon identifier. Values must
#'   be non-missing, non-blank, and unique after conversion to character.
#' @param attribute_cols Optional character vector naming polygon attributes
#'   to retain. `NULL` retains all non-geometry attributes. The identifier in
#'   `id_col` is always retained, including with `character(0)`.
#' @param output_dir Character scalar giving the output directory. There is no
#'   default; the caller must supply the directory explicitly.
#' @param file_stem Character scalar used before an optional geographic suffix.
#' @return A tibble preserving the rows and values of `means`, with the selected
#'   polygon attributes inserted between `polygon_id` and `date`.
#' @details
#' When `polygons` contains `state`, the filename suffix uses sorted lowercase
#' state codes. If it also contains `region` and covers all states of one
#' Brazilian region, that region name is used instead. Without `state`, only
#' `file_stem` is used. Filename metadata is read from `polygons` independently
#' of `attribute_cols`.
#' @export
join_and_write_municipal_means <- function(
    means,
    polygons,
    output_dir,
    id_col = "polygon_id",
    attribute_cols = NULL,
    file_stem = "area-weighted-means"
) {
  means <- tibble::as_tibble(means)
  checkmate::assert_string(id_col, min.chars = 1)
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_names(
    names(polygons),
    must.include = id_col
  )
  checkmate::assert_names(
    names(means),
    must.include = c("polygon_id", "date")
  )

  polygon_attributes <- sf::st_drop_geometry(polygons)
  if (!is.null(attribute_cols)) {
    checkmate::assert_character(attribute_cols, any.missing = FALSE, unique = TRUE)
    checkmate::assert_names(names(polygon_attributes), must.include = attribute_cols)
    retained_cols <- funique::funique(c(id_col, attribute_cols))
    polygon_attributes <- polygon_attributes[, retained_cols, drop = FALSE]
  }
  names(polygon_attributes)[names(polygon_attributes) == id_col] <- "polygon_id"
  polygon_attributes$polygon_id <- as.character(polygon_attributes$polygon_id)

  checkmate::assert_character(
    polygon_attributes$polygon_id,
    any.missing = FALSE,
    unique = TRUE,
    .var.name = paste0("polygons[[", id_col, "]] after conversion to character")
  )
  checkmate::assert_character(
    means$polygon_id,
    any.missing = FALSE,
    .var.name = "means$polygon_id"
  )
  if (any(!nzchar(trimws(polygon_attributes$polygon_id)))) {
    cli::cli_abort("`polygons[[id_col]]` must not contain blank identifiers.")
  }
  if (any(!nzchar(trimws(means$polygon_id)))) {
    cli::cli_abort("`means$polygon_id` must not contain blank identifiers.")
  }
  checkmate::assert_subset(
    funique::funique(means$polygon_id),
    choices = polygon_attributes$polygon_id,
    .var.name = "means$polygon_id present in polygons"
  )

  joined_means <- means |>
    dplyr::left_join(polygon_attributes, by = "polygon_id") |>
    dplyr::relocate(
      polygon_id,
      dplyr::all_of(setdiff(names(polygon_attributes), "polygon_id")),
      date
    ) |>
    tibble::as_tibble()

  checkmate::assert_character(
    file_stem,
    len = 1,
    min.chars = 1,
    pattern = "^[[:alnum:]][[:alnum:]-]*$"
  )
  area_suffix <- NULL
  if ("state" %in% names(polygons)) {
    state_ids <- sort(tolower(funique::funique(as.character(polygons$state))))
    checkmate::assert_character(state_ids, min.len = 1, any.missing = FALSE)
    checkmate::assert_true(all(grepl("^[[:alnum:]]+$", state_ids)))
    area_suffix <- paste(state_ids, collapse = "-")
    if ("region" %in% names(polygons)) {
      region_ids <- funique::funique(as.character(polygons$region))
      checkmate::assert_character(region_ids, min.len = 1, any.missing = FALSE)
      state_regions <- get_brazilian_state_regions()
      expected_regions <- state_regions$region[match(tolower(as.character(polygons$state)),
                                                    state_regions$state)]
      checkmate::assert_true(
        identical(as.character(polygons$region), expected_regions),
        .var.name = "region values matching Brazilian state codes"
      )
      if (length(region_ids) == 1L &&
          setequal(state_ids, state_regions$state[state_regions$region == region_ids])) {
        area_suffix <- region_ids
      }
    }
  }
  output_name <- if (is.null(area_suffix)) file_stem else paste(file_stem, area_suffix, sep = "-")
  output_path <- fs::path(output_dir, paste0(output_name, ".fst"))
  fs::dir_create(output_dir)
  fst::write_fst(joined_means, output_path)
  cli::cli_alert_success("Polygon means written to {.file {output_path}}.")

  joined_means
}
