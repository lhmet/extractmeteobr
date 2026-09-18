make_polygon_join_fixture <- function() {
  polygons <- sf::st_sf(
    code = c("a", "b"), state = c("rs", "rs"), region = c("sul", "sul"), polygon_name = c("A", "B"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0)))),
      sf::st_polygon(list(rbind(c(2, 0), c(3, 0), c(3, 1), c(2, 0)))),
      crs = 4326
    )
  )
  means <- tibble::tibble(
    polygon_id = c("a", "a", "b"),
    date = as.Date(c("2020-01-01", "2020-02-01", "2020-01-01")),
    pr = c(1, 2, 3)
  )
  list(polygons = polygons, means = means)
}

testthat::test_that("polygon join preserves repeated identifiers across dates", {
  fixture <- make_polygon_join_fixture()
  output_dir <- tempfile("polygon-output-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  result <- join_and_write_polygon_means(
    fixture$means, fixture$polygons, output_dir, id_col = "code"
  )
  testthat::expect_identical(result$polygon_id, fixture$means$polygon_id)
  testthat::expect_identical(result$date, fixture$means$date)
  testthat::expect_identical(result$pr, fixture$means$pr)
  testthat::expect_identical(result$polygon_name, c("A", "A", "B"))
  saved <- fst::read_fst(file.path(output_dir, "area-weighted-means-rs.fst"))
  testthat::expect_equal(saved, as.data.frame(result))
})

testthat::test_that("invalid identifiers fail before polygon output is created", {
  fixture <- make_polygon_join_fixture()
  output_dir <- tempfile("invalid-polygon-output-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  run_join <- function(means = fixture$means, polygons = fixture$polygons) {
    join_and_write_polygon_means(means, polygons, output_dir, id_col = "code")
  }
  for (ids in list(c("a", "a"), c("a", NA_character_), c("a", " "))) {
    polygons <- fixture$polygons
    polygons$code <- ids
    testthat::expect_error(run_join(polygons = polygons))
  }
  for (id in c(NA_character_, "", "unknown")) {
    means <- fixture$means
    means$polygon_id[1] <- id
    testthat::expect_error(run_join(means = means))
  }
  testthat::expect_false(dir.exists(output_dir))
})

testthat::test_that("attribute selection supports generic polygons and metadata suffixes", {
  fixture <- make_polygon_join_fixture()
  output_dir <- tempfile("selected-output-")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  selected <- join_and_write_polygon_means(
    fixture$means, fixture$polygons, output_dir, id_col = "code",
    attribute_cols = "polygon_name"
  )
  testthat::expect_named(selected, c("polygon_id", "polygon_name", "date", "pr"))
  testthat::expect_true(file.exists(file.path(output_dir, "area-weighted-means-rs.fst")))
  polygons <- fixture$polygons[, c("code", "polygon_name")]
  result <- join_and_write_polygon_means(
    fixture$means, polygons, output_dir, id_col = "code",
    attribute_cols = character(0), file_stem = "basin-means"
  )
  testthat::expect_named(result, c("polygon_id", "date", "pr"))
  testthat::expect_true(file.exists(file.path(output_dir, "basin-means.fst")))
  testthat::expect_error(join_and_write_polygon_means(
    fixture$means, polygons, output_dir, id_col = "code", attribute_cols = "unknown"
  ))
  polygons <- fixture$polygons[c(1, 2, 1), ]
  polygons$code <- c("a", "b", "c")
  polygons$state <- c("pr", "rs", "sc")
  means <- fixture$means
  means$polygon_id <- c("a", "b", "c")
  join_and_write_polygon_means(means, polygons, output_dir, id_col = "code")
  testthat::expect_true(file.exists(file.path(output_dir, "area-weighted-means-sul.fst")))
})
