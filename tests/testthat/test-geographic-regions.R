testthat::test_that("municipality loading includes state and region attributes", {
  fixture <- sf::st_sf(
    CD_MUN = c("a", "b"), NM_MUN = c("A", "B"), SIGLA_UF = c("RS", "SP"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0)))),
      sf::st_polygon(list(rbind(c(2, 0), c(3, 0), c(3, 1), c(2, 0)))),
      crs = 4326
    )
  )
  input_file <- tempfile(fileext = ".gpkg")
  on.exit(unlink(input_file), add = TRUE)
  sf::st_write(fixture, input_file, quiet = TRUE)
  result <- load_ibge_municipalities(c("rs", "sp"), input_file)
  testthat::expect_named(result, c("polygon_id", "municipality", "state", "region", "geom"))
  testthat::expect_identical(result$state, c("rs", "sp"))
  testthat::expect_identical(result$region, c("sul", "sudeste"))
  regions <- extractmeteobr:::get_brazilian_state_regions()
  testthat::expect_equal(nrow(regions), 27L)
  testthat::expect_identical(extractmeteobr:::resolve_brazilian_states("sul"), c("pr", "rs", "sc"))
})
