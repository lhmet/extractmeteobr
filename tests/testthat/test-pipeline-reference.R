testthat::test_that("pipeline reference follows requested variables and explicit CRS", {
  input_dir <- tempfile("monthly-")
  dir.create(input_dir)
  on.exit(unlink(input_dir, recursive = TRUE), add = TRUE)

  reference <- terra::rast(nrows = 1, ncols = 1, crs = "EPSG:4326")
  terra::values(reference) <- 1
  terra::time(reference) <- as.Date("2020-01-01")
  reference_file <- file.path(input_dir, "ETo_mly_fixture.nc")
  terra::writeCDF(reference, reference_file, varname = "ETo")
  received_crs <- NULL

  testthat::local_mocked_bindings(
    load_ibge_municipalities = function(states, target_crs, ...) {
      received_crs <<- target_crs
      NULL
    },
    crop_netcdfs = function(...) NULL,
    fill_missing_raster_cells = function(...) NULL,
    extract_area_weighted_mean = function(...) NULL,
    join_and_write_polygon_means = function(...) "completed"
  )

  result <- run_meteo_pipeline(
    states = "rs", monthly_data_path = input_dir,
    municipality_data_path = "unused.shp", output_dir = "unused",
    variables = "ETo", return_intermediate = FALSE
  )
  testthat::expect_identical(result, "completed")
  testthat::expect_true(sf::st_crs(received_crs) == sf::st_crs(4326))

  # An explicit CRS must not trigger raster reading or precipitation selection.
  writeLines("not a readable NetCDF", reference_file)
  run_meteo_pipeline(
    states = "rs", monthly_data_path = input_dir,
    municipality_data_path = "unused.shp", output_dir = "unused",
    variables = "ETo", target_crs = 4326, return_intermediate = FALSE
  )
  testthat::expect_identical(received_crs, 4326)

  testthat::expect_error(
    run_meteo_pipeline(
      states = "rs", monthly_data_path = input_dir,
      municipality_data_path = "unused.shp", output_dir = "unused",
      variables = "pr", return_intermediate = FALSE
    ),
    "No monthly NetCDF starts"
  )
})
