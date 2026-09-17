# Validar médias ponderadas pela área com dados reais do BR-DWGD
#
# Este script complementa os testes unitários sintéticos. Para um município e
# um mês reais, ele compara o resultado da matriz esparsa com a aplicação
# direta da equação da média ponderada pela área.
#
# Este script não faz parte da árvore instalável do pacote (veja
# `.Rbuildignore`) e não é executado por `devtools::test()` ou
# `devtools::check()`, pois depende de arquivos externos do BR-DWGD e do
# IBGE. Para executá-lo, carregue o pacote com `devtools::load_all()` (não
# apenas `library(extractmeteobr)`), pois ele usa `make_polygon_cell_weights()`
# e `calculate_area_weighted_mean()`, funções internas não exportadas.
#
# Os objetos de entrada devem existir previamente na sessão do R, por exemplo
# como saída de `run_meteo_pipeline(..., return_intermediate = TRUE)`:
#
# * `filled_monthly_rasters` ou `monthly_rasters`: lista nomeada de
#   SpatRaster;
# * `municipalities`: objeto sf contendo os polígonos municipais, com a
#   coluna `polygon_id`.


validate_area_weighted_mean_real_data <- function(
    r_list,
    polygons,
    id_col,
    polygon_id,
    variable,
    date,
    tolerance = 1e-12
) {
  # ETAPA 1: Validar variável, município, data e tolerância solicitados.
  checkmate::assert_list(r_list, min.len = 1)
  checkmate::assert_names(names(r_list), must.include = variable)
  checkmate::assert_class(polygons, "sf")
  checkmate::assert_string(id_col, min.chars = 1)
  checkmate::assert_names(names(polygons), must.include = id_col)
  checkmate::assert_string(variable, min.chars = 1)
  checkmate::assert_date(date, len = 1)
  checkmate::assert_number(
    tolerance,
    lower = 0,
    finite = TRUE
  )

  checkmate::assert_true(
    !anyNA(polygons[[id_col]]) &&
      !anyDuplicated(polygons[[id_col]])
  )

  polygon_row <- match(
    polygon_id,
    polygons[[id_col]]
  )

  checkmate::assert_true(!is.na(polygon_row))

  variable_raster <- r_list[[variable]]
  checkmate::assert_class(variable_raster, "SpatRaster")

  # ETAPA 2: Identificar a camada do raster associada ao mês solicitado.
  # O índice temporal do terra tem prioridade. Os nomes das camadas são usados
  # somente se esse índice não estiver disponível.
  raster_dates <- terra::time(variable_raster)

  if (
    length(raster_dates) != terra::nlyr(variable_raster) ||
    all(is.na(raster_dates))
  ) {
    raster_dates <- lubridate::ymd(names(variable_raster))
  }

  raster_dates <- lubridate::as_date(raster_dates)
  layer_index <- which(raster_dates == date)

  checkmate::assert_true(length(layer_index) == 1)

  raster_layer <- variable_raster[[layer_index]]
  terra::time(raster_layer) <- date
  names(raster_layer) <- as.character(date)

  # ETAPA 3: Selecionar um município preservando sua geometria sf.
  municipality <- polygons[polygon_row, , drop = FALSE]
  polygon_ids <- as.character(municipality[[id_col]])

  # ETAPA 4: Calcular as interseções exatas entre células e município de
  # forma independente da função em avaliação (make_polygon_cell_weights()),
  # para servir de referência transparente. `fraction` é a fração da célula
  # contida no município e `cell_area` é a área física completa da célula.
  raw_intersections <- terra::extract(
    raster_layer,
    terra::vect(municipality),
    cells = TRUE,
    exact = TRUE
  ) |>
    data.table::as.data.table()

  checkmate::assert_data_frame(raw_intersections, min.rows = 1)
  checkmate::assert_true(
    any(raw_intersections$fraction > 0 & raw_intersections$fraction < 1)
  )

  cell_area_values <- terra::extract(
    terra::cellSize(raster_layer, unit = "m"),
    raw_intersections$cell,
    raw = TRUE
  )[, 1]
  raw_intersections[, cell_area := cell_area_values]

  # ETAPA 5: Extrair o valor do raster em cada célula interceptada.
  cell_values <- terra::extract(
    raster_layer,
    raw_intersections$cell,
    raw = TRUE
  )[, 1]

  cell_details <- data.table::copy(raw_intersections)
  cell_details[, value := as.numeric(cell_values)]
  cell_details[, valid := !is.na(value)]

  # Recalcular explicitamente os pesos, sem reutilizar `area_weight` de
  # make_polygon_cell_weights(). Assim, o cálculo de referência permanece
  # visivelmente ligado à equação:
  #
  #   peso[i] = fração[i] * área_da_célula[i]
  cell_details[
    ,
    explicit_weight := fraction * cell_area
  ]

  # A referência explícita à coluna evita que data.table procure `valid` no
  # escopo externo quando o primeiro argumento de DT[...] é um único símbolo.
  valid_cells <- cell_details[valid == TRUE]
  checkmate::assert_true(nrow(valid_cells) > 0)

  # ETAPA 6: Aplicar termo a termo a equação que define a média.
  #
  #   média explícita = soma(valor[i] * fração[i] * área[i]) /
  #                     soma(fração[i] * área[i])
  explicit_numerator <- valid_cells[
    ,
    sum(value * explicit_weight)
  ]

  explicit_denominator <- valid_cells[
    ,
    sum(explicit_weight)
  ]

  explicit_mean <- explicit_numerator / explicit_denominator

  cell_details[
    ,
    weighted_contribution := data.table::fifelse(
      valid,
      value * explicit_weight,
      NA_real_
    )
  ]

  # ETAPA 7: Calcular a mesma média pelo método da matriz esparsa, usando as
  # funções internas do pacote (make_polygon_cell_weights() e
  # calculate_area_weighted_mean()), disponíveis após devtools::load_all().
  cell_weights <- make_polygon_cell_weights(
    raster = raster_layer,
    polygons = municipality,
    polygon_ids = polygon_ids
  )

  sparse_result <- calculate_area_weighted_mean(
    raster = raster_layer,
    cell_weights = cell_weights,
    polygon_ids = polygon_ids,
    variable = variable
  )

  sparse_mean <- sparse_result$value[[1]]

  # ETAPA 8: Verificar a concordância dentro da tolerância declarada.
  testthat::expect_equal(
    sparse_mean,
    explicit_mean,
    tolerance = tolerance
  )

  absolute_difference <- abs(sparse_mean - explicit_mean)

  relative_difference <- if (explicit_mean == 0) {
    if (sparse_mean == 0) 0 else Inf
  } else {
    absolute_difference / abs(explicit_mean)
  }

  # ETAPA 9: Processar a mesma amostra pela função de alto nível
  # extract_area_weighted_mean(), que recalcula os pesos internamente (não
  # aceita `cell_weights` pré-calculados).
  sample_rasters <- stats::setNames(
    list(raster_layer),
    variable
  )

  wrapper_result <- extract_area_weighted_mean(
    rasters = sample_rasters,
    polygons = municipality,
    id_col = id_col
  )

  wrapper_mean <- wrapper_result[[variable]][[1]]

  testthat::expect_equal(
    wrapper_mean,
    explicit_mean,
    tolerance = tolerance
  )

  # ETAPA 10: Resumir a cobertura dos dados e a concordância numérica.
  total_intersection_area <- sum(cell_details$explicit_weight)
  valid_intersection_area <- sum(valid_cells$explicit_weight)

  validation_summary <- tibble::tibble(
    polygon_id = polygon_id,
    date = date,
    variable = variable,
    intersecting_cells = nrow(cell_details),
    partial_cells = sum(
      cell_details$fraction > 0 & cell_details$fraction < 1
    ),
    missing_cells = sum(!cell_details$valid),
    zero_cells = sum(cell_details$value == 0, na.rm = TRUE),
    valid_area_fraction = valid_intersection_area /
      total_intersection_area,
    explicit_mean = explicit_mean,
    sparse_mean = sparse_mean,
    wrapper_mean = wrapper_mean,
    absolute_difference = absolute_difference,
    relative_difference = relative_difference,
    tolerance = tolerance,
    validation_passed = isTRUE(
      all.equal(
        sparse_mean,
        explicit_mean,
        tolerance = tolerance
      )
    )
  )

  list(
    summary = validation_summary,
    cells = cell_details[],
    sparse_result = sparse_result,
    wrapper_result = wrapper_result
  )
}



# EXEMPLO COM OS DADOS DO PROJETO
# -------------------------------
# Execute primeiro o pipeline (ex.: run_meteo_pipeline(..., return_intermediate
# = TRUE)) para obter `filled_monthly_rasters` (ou `monthly_rasters`) e
# `municipalities`. Depois, selecione um município, uma variável e um mês.

municipality_name <- "Chuí"

municipality_id <- municipalities$polygon_id[
  municipalities$municipality == municipality_name
]

checkmate::assert_true(length(municipality_id) == 1)

validation <- validate_area_weighted_mean_real_data(
  r_list = filled_monthly_rasters,
  polygons = municipalities,
  id_col = "polygon_id",
  polygon_id = municipality_id,
  variable = "pr",
  date = as.Date("2020-01-01"),
  tolerance = 1e-12
)

validation$summary
validation$cells

# Para examinar células naturalmente ausentes antes do preenchimento por IDW,
# substitua `filled_monthly_rasters` por `monthly_rasters`. O mês e o
# município devem conter ao menos uma célula válida, pois não existe média
# numérica quando todas as células interceptadas estão ausentes.
