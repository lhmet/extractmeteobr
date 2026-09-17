#' Map Brazilian state codes to their geographic regions
#' @return A tibble with lowercase state and region columns.
#' @keywords internal
#' @noRd
get_brazilian_state_regions <- function() {
  tibble::tibble(
    state = c("ac", "ap", "am", "pa", "ro", "rr", "to",
              "al", "ba", "ce", "ma", "pb", "pe", "pi", "rn", "se",
              "df", "go", "mt", "ms", "es", "mg", "rj", "sp",
              "pr", "rs", "sc"),
    region = rep(c("norte", "nordeste", "centro-oeste", "sudeste", "sul"),
                 times = c(7, 9, 4, 4, 3))
  )
}

#' Resolve Brazilian regions and state codes
#'
#' @param states Character vector containing lowercase state codes or one
#'   lowercase Brazilian region name.
#'
#' @return A lowercase character vector of two-letter state codes.
#'
#' @keywords internal
#' @noRd
resolve_brazilian_states <- function(states) {
  state_regions <- get_brazilian_state_regions()

  checkmate::assert_character(
    states,
    min.len = 1,
    any.missing = FALSE,
    unique = TRUE
  )
  checkmate::assert_true(
    identical(states, tolower(states)),
    .var.name = "states in lowercase"
  )

  if (length(states) == 1L && states %in% state_regions$region) {
    return(state_regions$state[state_regions$region == states])
  }

  checkmate::assert_character(
    states,
    pattern = "^[a-z]{2}$",
    .var.name = "lowercase Brazilian state codes"
  )

  valid_states <- sort(funique::funique(state_regions$state))
  checkmate::assert_subset(states, choices = valid_states)
  states
}

#' Load and standardize polygon data
#'
#' Reads polygon features from a spatial vector file, optionally filters them,
#' validates their identifiers and geometries, repairs invalid geometries, and
#' optionally transforms them to a target coordinate reference system (CRS).
#'
#' @param data_path Character scalar giving the spatial vector file path.
#' @param id_column Character scalar naming the source identifier column.
#' @param target_crs Optional CRS accepted by [sf::st_crs()], such as an EPSG
#'   code, WKT string, or `crs` object. When `NULL`, the source CRS is retained.
#' @param filter_column Optional character scalar naming a column used to
#'   select features.
#' @param filter_values Optional atomic vector containing the values to retain
#'   from `filter_column`. It must be supplied together with `filter_column`.
#'
#' @return An `sf` object containing the selected polygon features. A character
#'   column named `polygon_id`, copied from `id_column`, is placed first. Source
#'   attributes and the active geometry column are preserved.
#'
#' @details
#' The function accepts `POLYGON` and `MULTIPOLYGON` geometries. Empty
#' geometries, missing identifiers, duplicated identifiers, absent filter
#' values, and missing source CRS information cause an error. Geometry repair
#' is performed with [sf::st_make_valid()] before any CRS transformation.
#'
#' @examples
#' \dontrun{
#' municipalities <- load_polygon_data(
#'   data_path = "path/to/municipalities.shp",
#'   id_column = "CD_MUN",
#'   target_crs = 4326,
#'   filter_column = "SIGLA_UF",
#'   filter_values = "RS"
#' )
#' }
#'
#' @importFrom checkmate assert_atomic_vector assert_character
#' @importFrom checkmate assert_file_exists assert_names assert_string
#' @importFrom checkmate assert_subset assert_true
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @importFrom sf st_crs st_geometry_type st_is_empty st_make_valid st_read
#' @importFrom sf st_transform
#'
#' @export
load_polygon_data <- function(
    data_path,
    id_column,
    target_crs = NULL,
    filter_column = NULL,
    filter_values = NULL
) {
  checkmate::assert_file_exists(data_path, access = "r")
  checkmate::assert_string(id_column, min.chars = 1)

  filter_requested <- !is.null(filter_column) || !is.null(filter_values)
  filter_complete <- !is.null(filter_column) && !is.null(filter_values)

  if (filter_requested && !filter_complete) {
    cli::cli_abort(c(
      "Polygon filtering is incompletely specified.",
      "x" = "`filter_column` and `filter_values` must be supplied together."
    ))
  }

  if (filter_complete) {
    checkmate::assert_string(filter_column, min.chars = 1)
    checkmate::assert_atomic_vector(
      filter_values,
      min.len = 1,
      any.missing = FALSE,
      unique = TRUE
    )
  }

  cli::cli_alert_info("Reading polygon data from {.file {data_path}}.")
  polygons <- sf::st_read(data_path, quiet = TRUE)

  checkmate::assert_class(polygons, "sf")
  checkmate::assert_names(
    names(polygons),
    must.include = id_column
  )

  if (filter_complete) {
    checkmate::assert_names(
      names(polygons),
      must.include = filter_column
    )
    checkmate::assert_subset(
      filter_values,
      choices = funique::funique(polygons[[filter_column]]),
      .var.name = "filter_values present in filter_column"
    )

    polygons <- polygons[
      polygons[[filter_column]] %in% filter_values,
      ,
      drop = FALSE
    ]
  }

  checkmate::assert_true(
    nrow(polygons) > 0,
    .var.name = "number of selected polygon features"
  )

  geometry_types <- funique::funique(as.character(sf::st_geometry_type(polygons)))
  checkmate::assert_subset(
    geometry_types,
    choices = c("POLYGON", "MULTIPOLYGON"),
    .var.name = "geometry types"
  )
  checkmate::assert_true(
    !any(sf::st_is_empty(polygons)),
    .var.name = "absence of empty geometries"
  )

  polygon_ids <- polygons[[id_column]]
  checkmate::assert_atomic_vector(
    polygon_ids,
    len = nrow(polygons),
    any.missing = FALSE
  )
  checkmate::assert_true(
    !anyDuplicated(polygon_ids),
    .var.name = "unique polygon identifiers"
  )

  source_crs <- sf::st_crs(polygons)
  if (is.na(source_crs)) {
    cli::cli_abort(c(
      "Polygon data do not have a defined CRS.",
      "x" = "A source CRS is required for reliable spatial operations."
    ))
  }

  polygons <- sf::st_make_valid(polygons)
  polygons$polygon_id <- as.character(polygon_ids)

  geometry_column <- attr(polygons, "sf_column")
  attribute_columns <- setdiff(names(polygons), c("polygon_id", geometry_column))
  polygons <- polygons[
    c("polygon_id", attribute_columns, geometry_column)
  ]

  if (!is.null(target_crs)) {
    target_crs <- sf::st_crs(target_crs)
    if (is.na(target_crs)) {
      cli::cli_abort(c(
        "`target_crs` is not a valid coordinate reference system.",
        "x" = "Supply a valid EPSG code, WKT string, or `crs` object."
      ))
    }
    polygons <- sf::st_transform(polygons, crs = target_crs)
  }

  cli::cli_alert_success(
    "Loaded {nrow(polygons)} polygon feature(s) from {.file {data_path}}."
  )

  polygons
}

#' Load IBGE municipality polygons
#'
#' Loads municipalities for one or more Brazilian states through
#' [load_polygon_data()] and standardizes the attributes used by this project.
#'
#' @param states Character vector containing unique two-letter Brazilian state
#'   abbreviations, such as `"RS"` or `c("RS", "SC")`.
#' @param data_path Character scalar giving the IBGE municipality vector file.
#'   There is no default; the caller must supply the file path explicitly.
#' @param target_crs Optional target CRS accepted by [sf::st_crs()]. When
#'   `NULL`, the source IBGE CRS is retained.
#' @param remove_lagoons Logical scalar. If `TRUE`, removes the features named
#'   `"Lagoa Mirim"` and `"Lagoa dos Patos"`.
#'
#' @return An `sf` object with the columns `polygon_id`, `municipality`,
#'   `state`, `region`, and geometry. State codes and region names are lowercase.
#'   Each row represents one municipality or retained
#'   IBGE feature.
#'
#' @details
#' The project examples use the IBGE 2022 edition of the Malha Municipal
#' Digital. Obtain the vector data separately and keep the extracted Shapefile
#' components together. This function reads the file supplied in `data_path`;
#' it does not download data or require the 2022 edition when another edition
#' has compatible attributes.
#'
#' @references
#' IBGE. Malha Municipal Digital, 2022 edition:
#' [official product page](https://www.ibge.gov.br/geociencias/organizacao-do-territorio/malhas-territoriais/15774-malhas.html?edicao=36516&t=acesso-ao-produto).
#' Municipality data: [BR_Municipios_2022.zip](https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2022/Brasil/BR/BR_Municipios_2022.zip).
#'
#' IBGE. Malha Municipal Digital e Áreas Territoriais 2022: Informações
#' Técnicas e Legais para a Utilização dos Dados Publicados.
#' [Technical documentation](https://biblioteca.ibge.gov.br/visualizacao/livros/liv101998.pdf).
#' Source links consulted on 2026-09-17; the original local download date
#' is not recorded.
#'
#' @examples
#' \dontrun{
#' municipalities <- load_ibge_municipalities(
#'   states = "rs",
#'   data_path = "path/to/BR_Municipios_2022.shp",
#'   target_crs = 4326
#' )
#' }
#'
#' @importFrom checkmate assert_character assert_file_exists assert_flag
#' @importFrom dplyr select
#'
#' @export
load_ibge_municipalities <- function(
    states,
    data_path,
    target_crs = NULL,
    remove_lagoons = FALSE
) {
  states <- resolve_brazilian_states(states)
  checkmate::assert_flag(remove_lagoons)

  municipalities <- load_polygon_data(
    data_path = data_path,
    id_column = "CD_MUN",
    target_crs = target_crs,
    filter_column = "SIGLA_UF",
    filter_values = toupper(states)
  )

  required_columns <- c("NM_MUN", "SIGLA_UF")
  checkmate::assert_names(
    names(municipalities),
    must.include = required_columns
  )

  names(municipalities)[names(municipalities) == "NM_MUN"] <- "municipality"
  names(municipalities)[names(municipalities) == "SIGLA_UF"] <- "state"
  municipalities$state <- tolower(municipalities$state)
  state_regions <- get_brazilian_state_regions()
  municipalities$region <- state_regions$region[
    match(municipalities$state, state_regions$state)
  ]

  if (remove_lagoons) {
    lagoon_names <- c("Lagoa Mirim", "Lagoa dos Patos")
    municipalities <- municipalities[
      !municipalities$municipality %in% lagoon_names,
      ,
      drop = FALSE
    ]
  }

  municipalities |>
    dplyr::select(dplyr::all_of(c("polygon_id", "municipality", "state", "region")))
}

#' Load IBGE state polygons
#'
#' Loads polygons for Brazilian states and optionally combines them into one
#' feature without discarding islands or other valid polygon components.
#'
#' @inheritParams load_ibge_municipalities
#' @param data_path Character scalar giving the IBGE state vector file. There
#'   is no default; the caller must supply the file path explicitly.
#' @param union_states Logical scalar. If `TRUE`, combines all requested states
#'   into a single feature. If `FALSE`, retains one feature per state.
#'
#' @return An `sf` object containing `polygon_id`, `state`, and geometry. With
#'   `union_states = TRUE`, it contains one combined feature.
#'
#' @details
#' The project examples use the IBGE 2022 edition of the Malha Municipal
#' Digital. Obtain the vector data separately and keep the extracted Shapefile
#' components together. This function reads the file supplied in `data_path`;
#' it does not download data or require the 2022 edition when another edition
#' has compatible attributes.
#'
#' @references
#' IBGE. Malha Municipal Digital, 2022 edition:
#' [official product page](https://www.ibge.gov.br/geociencias/organizacao-do-territorio/malhas-territoriais/15774-malhas.html?edicao=36516&t=acesso-ao-produto).
#' State data: [BR_UF_2022.zip](https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2022/Brasil/BR/BR_UF_2022.zip).
#'
#' IBGE. Malha Municipal Digital e Áreas Territoriais 2022: Informações
#' Técnicas e Legais para a Utilização dos Dados Publicados.
#' [Technical documentation](https://biblioteca.ibge.gov.br/visualizacao/livros/liv101998.pdf).
#' Source links consulted on 2026-09-17; the original local download date
#' is not recorded.
#'
#' @examples
#' \dontrun{
#' southern_states <- load_ibge_states(
#'   states = "sul",
#'   data_path = "path/to/BR_UF_2022.shp",
#'   target_crs = 4326,
#'   union_states = TRUE
#' )
#' }
#'
#' @importFrom checkmate assert_character assert_flag assert_names
#' @importFrom dplyr select
#' @importFrom sf st_geometry st_sf st_union
#'
#' @export
load_ibge_states <- function(
    states,
    data_path,
    target_crs = NULL,
    union_states = TRUE
) {
  states <- resolve_brazilian_states(states)
  checkmate::assert_flag(union_states)

  state_polygons <- load_polygon_data(
    data_path = data_path,
    id_column = "CD_UF",
    target_crs = target_crs,
    filter_column = "SIGLA_UF",
    filter_values = toupper(states)
  )

  checkmate::assert_names(
    names(state_polygons),
    must.include = "SIGLA_UF"
  )
  names(state_polygons)[names(state_polygons) == "SIGLA_UF"] <- "state"
  state_polygons$state <- tolower(state_polygons$state)

  state_polygons <- state_polygons |>
    dplyr::select(polygon_id, state)

  if (!union_states) {
    return(state_polygons)
  }

  combined_geometry <- sf::st_union(sf::st_geometry(state_polygons))
  combined_id <- paste(states, collapse = "_")

  sf::st_sf(
    polygon_id = combined_id,
    geometry = combined_geometry
  )
}

#' Select the largest polygon feature
#'
#' Splits `MULTIPOLYGON` geometries into polygon components and returns the
#' component with the largest geodesic or projected area, according to the
#' input CRS.
#'
#' @param polygons An `sf` object containing at least one `POLYGON` or
#'   `MULTIPOLYGON` feature and a defined CRS.
#'
#' @return An `sf` object containing the largest polygon component. Source
#'   attributes are preserved from the originating feature.
#'
#' @examples
#' \dontrun{
#' largest_state_component <- select_largest_polygon(state_polygons)
#' }
#'
#' @importFrom checkmate assert_class assert_subset assert_true
#' @importFrom dplyr slice_max
#' @importFrom sf st_area st_cast st_crs st_geometry_type
#'
#' @export
select_largest_polygon <- function(polygons) {
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_true(
    nrow(polygons) > 0,
    .var.name = "number of polygon features"
  )
  checkmate::assert_true(
    !is.na(sf::st_crs(polygons)),
    .var.name = "defined polygon CRS"
  )

  geometry_types <- funique::funique(as.character(sf::st_geometry_type(polygons)))
  checkmate::assert_subset(
    geometry_types,
    choices = c("POLYGON", "MULTIPOLYGON"),
    .var.name = "geometry types"
  )

  polygon_parts <- sf::st_cast(
    polygons,
    to = "POLYGON",
    warn = FALSE
  )
  polygon_parts$area <- sf::st_area(polygon_parts)

  polygon_parts |>
    dplyr::slice_max(
      order_by = area,
      n = 1,
      with_ties = FALSE
    ) |>
    dplyr::select(-area)
}
