testthat::test_that("interactive maps retain popup fields and hover labels", {
  testthat::skip_if_not_installed("tmap", minimum_version = "4.0")
  previous_mode <- tmap::tmap_mode()

  polygons <- sf::st_sf(
    name = "Reference polygon",
    observed = 42,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(0, 0), c(1000, 0), c(1000, 1000), c(0, 1000), c(0, 0)
      ))),
      crs = 3857
    )
  )
  sf::st_agr(polygons) <- "constant"

  widget <- tryCatch({
    map <- make_interactive_spatial_map(
      polygons = polygons,
      popup_vars = c("Observed value" = "observed"),
      popup_title = "name"
    )
    testthat::expect_s3_class(map, "tmap")
    # Rendering catches invalid arguments that map construction can defer.
    tmap::tmap_leaflet(map)
  }, finally = tmap::tmap_mode(previous_mode))

  testthat::expect_s3_class(widget, "leaflet")
  point_calls <- Filter(
    function(call) identical(call$method, "addCircleMarkers"),
    widget$x$calls
  )
  testthat::expect_length(point_calls, 1L)
  point_content <- unlist(point_calls[[1]]$args, use.names = FALSE)
  testthat::expect_true(any(grepl("Observed value", point_content, fixed = TRUE)))
  testthat::expect_true(any(grepl("Reference polygon", point_content, fixed = TRUE)))
  testthat::expect_true("Reference polygon" %in% point_content)
})
