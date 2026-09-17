#' Create an interactive map of polygons and an optional raster
#'
#' Builds an interactive `tmap` with polygon boundaries, internal clickable
#' points and, optionally, a raster layer with a labelled legend.
#'
#' @param polygons An `sf` object containing polygon geometries.
#' @param popup_vars Named character vector associating popup labels with
#'   columns in `polygons`, such as
#'   `c("Municipality" = "municipality", "State" = "state")`.
#' @param popup_title Character scalar naming the column used as the popup
#'   title and hover label.
#' @param raster Optional single-layer `SpatRaster` to display below the
#'   polygons.
#' @param raster_label Character scalar describing `raster`. Required when
#'   `raster` is supplied.
#' @param raster_units Character scalar containing the units of `raster`.
#'   Required when `raster` is supplied.
#'
#' @return A `tmap` object in interactive view mode.
#'
#' @details
#' One point is created inside each polygon with
#' [sf::st_point_on_surface()]. Clicking a point displays the attributes
#' selected by `popup_vars`; hovering displays `popup_title`.
#' The function supports `tmap` version 4.0 and later. It uses `tm_popup()`
#' when exported by the installed version, otherwise the equivalent
#' `popup.vars` and `id` layer arguments.
#'
#' If `raster` has a time coordinate, its first time value is appended to the
#' map title. The caller remains responsible for selecting the raster layer to
#' display.
#'
#' @examples
#' \dontrun{
#' municipality_map <- make_interactive_spatial_map(
#'   polygons = municipalities,
#'   popup_vars = c(
#'     "Municipality" = "municipality",
#'     "State" = "state"
#'   ),
#'   popup_title = "municipality"
#' )
#'
#' print(municipality_map)
#' }
#'
#' @export
make_interactive_spatial_map <- function(
  polygons,
  popup_vars,
  popup_title,
  raster = NULL,
  raster_label = NULL,
  raster_units = NULL
) {
  if (!requireNamespace("tmap", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg tmap} package is required to build interactive maps.",
      "i" = "Install it with {.code install.packages(\"tmap\")}."
    ))
  }
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_character(
    popup_vars,
    min.len = 1,
    any.missing = FALSE,
    names = "unique"
  )
  checkmate::assert_subset(unname(popup_vars), choices = names(polygons))
  checkmate::assert_choice(popup_title, choices = names(polygons))

  polygon_points <- sf::st_point_on_surface(polygons)
  polygon_color <- if (is.null(raster)) "#2C7FB8" else "#238B45"
  polygon_fill_alpha <- if (is.null(raster)) 0.1 else 0

  # tmap 4.0 uses layer arguments for popups; later versions export tm_popup().
  popup_options <- if ("tm_popup" %in% getNamespaceExports("tmap")) {
    list(
      popup = getExportedValue("tmap", "tm_popup")(
        vars = popup_vars,
        title = popup_title
      )
    )
  } else {
    list(popup.vars = popup_vars, id = popup_title)
  }
  tmap::tmap_mode("view")
  point_layer <- do.call(
    tmap::tm_dots,
    c(
      list(fill = "#D7301F", size = 0.05, hover = popup_title),
      popup_options
    )
  )

  map <-
    tmap::tm_shape(polygons) +
    tmap::tm_polygons(
      fill = "white",
      fill_alpha = polygon_fill_alpha,
      col = polygon_color
    ) +
    tmap::tm_shape(polygon_points) +
    point_layer

  if (!is.null(raster)) {
    checkmate::assert_class(raster, "SpatRaster")
    checkmate::assert_true(
      terra::nlyr(raster) == 1,
      .var.name = "raster (a single-layer SpatRaster)"
    )
    checkmate::assert_string(raster_label, min.chars = 1)
    checkmate::assert_string(raster_units, min.chars = 1)

    map_title <- raster_label
    if (terra::has.time(raster)) {
      map_title <- paste(raster_label, as.character(terra::time(raster)))
    }

    map <-
      tmap::tm_shape(raster) +
      tmap::tm_raster(
        col.legend = tmap::tm_legend(
          title = paste0(raster_label, " (", raster_units, ")")
        )
      ) +
      map +
      tmap::tm_title(map_title)
  }

  map
}
