testthat::test_that("complete pipeline handles each variable combination and CRS mode", {
  workspace <- tempfile("pipeline-combinations-")
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  dates <- as.Date(c("2020-01-01", "2020-02-01"))
  expected_values <- list(pr = c(10, 20), ETo = c(2, 4))

  municipalities <- sf::st_sf(
    CD_MUN = "4300001", NM_MUN = "Synthetic municipality", SIGLA_UF = "RS",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(-52, -30), c(-51, -30), c(-51, -29), c(-52, -29), c(-52, -30)
    ))), crs = 4326)
  )
  # Loading must transform the input polygons to the raster CRS in both modes.
  municipalities <- sf::st_transform(municipalities, 3857)
  municipality_file <- file.path(workspace, "municipalities.gpkg")
  sf::st_write(municipalities, municipality_file, quiet = TRUE)

  for (variables in list("pr", "ETo", c("pr", "ETo"))) {
    input_dir <- file.path(workspace, paste(variables, collapse = "-"))
    dir.create(input_dir)
    for (variable in variables) {
      raster <- terra::rast(
        nrows = 2, ncols = 2, nlyrs = 2,
        xmin = -52, xmax = -50, ymin = -30, ymax = -28, crs = "EPSG:4326"
      )
      # Constant layers give independent expected means for any positive weights.
      terra::values(raster) <- matrix(
        rep(expected_values[[variable]], each = 4), nrow = 4
      )
      terra::time(raster) <- dates
      terra::writeCDF(
        raster, file.path(input_dir, paste0(variable, "_mly_fixture.nc")),
        varname = variable
      )
    }
    for (explicit_crs in c(FALSE, TRUE)) {
      scenario <- paste(paste(variables, collapse = "+"),
                        if (explicit_crs) "explicit" else "automatic")
      output_dir <- file.path(input_dir, if (explicit_crs) "explicit" else "automatic")
      result <- run_meteo_pipeline(
        states = "rs", monthly_data_path = input_dir,
        municipality_data_path = municipality_file, output_dir = output_dir,
        variables = variables, target_crs = if (explicit_crs) 4326 else NULL,
        return_intermediate = !explicit_crs
      )
      if (!explicit_crs) {
        testthat::expect_true(sf::st_crs(result$municipalities) == sf::st_crs(4326),
                              info = scenario)
        testthat::expect_named(result$filled_monthly_rasters, variables, info = scenario)
        means <- result$municipal_monthly_means
      } else {
        means <- result
      }
      testthat::expect_s3_class(means, "tbl_df")
      testthat::expect_equal(nrow(means), 2L, info = scenario)
      testthat::expect_identical(means$polygon_id, rep("4300001", 2), info = scenario)
      testthat::expect_identical(means$date, dates, info = scenario)
      testthat::expect_identical(means$state, rep("rs", 2), info = scenario)
      testthat::expect_identical(means$region, rep("sul", 2), info = scenario)
      testthat::expect_setequal(names(means),
        c("polygon_id", "municipality", "state", "region", "date", variables))
      for (variable in variables) {
        testthat::expect_equal(means[[variable]], expected_values[[variable]],
                              tolerance = 1e-12, info = scenario)
      }
      output_file <- file.path(output_dir, "municipal-monthly-meteorology-rs.fst")
      testthat::expect_true(file.exists(output_file), info = scenario)
      testthat::expect_equal(fst::read_fst(output_file), as.data.frame(means), info = scenario)
    }
  }
})
