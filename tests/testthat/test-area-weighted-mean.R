# Validação numérica das médias por polígono ponderadas pela área
#
# OBJETIVO DESTE ARQUIVO
# ----------------------
# Este arquivo verifica se as médias ponderadas pela área calculadas com a
# matriz esparsa concordam com a aplicação direta da equação que define a
# média:
#
#   média ponderada = soma(valor * fração * área da célula) /
#                     soma(fração * área da célula)
#
# Os dados sintéticos são usados deliberadamente. Eles permitem controlar a
# localização exata de valores ausentes, zeros observados, células parcialmente
# interceptadas e um polígono pequeno na borda. Uma amostra pequena dos dados
# reais do BR-DWGD não garante a ocorrência de todas essas situações.
#
# Os testes estão organizados em três partes:
#
# 1. criar um raster pequeno e dois polígonos que representam municípios;
# 2. calcular explicitamente a média de referência, sem matriz esparsa;
# 3. comparar as funções do projeto com o comportamento esperado.
#
# NOTA DE MANUTENÇÃO: `make_polygon_cell_weights()` já retorna o peso espacial
# fundido `area_weight` (fração da célula multiplicada pela área física da
# célula, em m2), em vez de expor `fraction` e `cell_area` separadamente. A
# referência explícita usa `area_weight` diretamente, o que é equivalente à
# fórmula acima. A verificação de interseção parcial (TESTE 2) usa
# `terra::extract(..., exact = TRUE)` de forma independente, sem depender do
# formato interno de `make_polygon_cell_weights()`.

make_area_weighted_fixture <- function() {
  # ETAPA 1: Criar um raster vazio com 3 linhas e 3 colunas.
  #
  # O raster cobre longitude 0 a 3 e latitude 0 a 3. Portanto, cada célula tem
  # dimensão angular de 1 x 1 grau. O terra numera as células da esquerda para
  # a direita e da linha superior para a inferior:
  #
  #   cells:    1  2  3
  #             4  5  6
  #             7  8  9
  raster_template <- terra::rast(
    nrows = 3,
    ncols = 3,
    xmin = 0,
    xmax = 3,
    ymin = 0,
    ymax = 3,
    crs = "EPSG:4326"
  )

  # ETAPA 2: Criar a primeira camada mensal.
  #
  # A célula 4 contém um zero observado e a célula 5 contém NA. As demais
  # células têm valores positivos. Essa camada permite verificar se zero e NA
  # recebem tratamentos diferentes.
  #
  #   values:   1   2  3
  #             0  NA  6
  #             7   8  9
  observed <- raster_template
  terra::values(observed) <- c(
    1, 2, 3,
    0, NA, 6,
    7, 8, 9
  )

  # ETAPA 3: Criar um mês sem observações válidas em nenhuma célula.
  # A média correta dos polígonos nesta camada deve ser NA, e não zero.
  all_missing <- raster_template
  terra::values(all_missing) <- NA_real_

  # ETAPA 4: Criar um mês em que todas as células têm zero observado.
  # A média correta dos polígonos nesta camada deve ser exatamente zero.
  observed_zero <- raster_template
  terra::values(observed_zero) <- 0

  # ETAPA 5: Reunir os três meses em um SpatRaster multicamada e associar uma
  # data inequívoca a cada camada.
  climate_raster <- c(observed, all_missing, observed_zero)
  names(climate_raster) <- c(
    "2020-01-01",
    "2020-02-01",
    "2020-03-01"
  )
  terra::time(climate_raster) <- as.Date(names(climate_raster))

  # ETAPA 6: Criar o município de referência.
  #
  # Seus limites não coincidem com as linhas da grade. Por isso, ele intercepta
  # parcialmente as células 4, 5, 7 e 8. Entre elas, a célula 4 contém zero e
  # a célula 5 contém NA.
  reference_geometry <- sf::st_polygon(
    list(
      rbind(
        c(0.25, 0.25),
        c(1.75, 0.25),
        c(1.75, 1.75),
        c(0.25, 1.75),
        c(0.25, 0.25)
      )
    )
  )

  # ETAPA 7: Criar um município muito pequeno dentro da célula superior direita
  # da borda. Isso verifica se um polígono muito menor que uma célula ainda
  # recebe um resultado válido.
  border_geometry <- sf::st_polygon(
    list(
      rbind(
        c(2.70, 2.70),
        c(2.95, 2.70),
        c(2.95, 2.95),
        c(2.70, 2.95),
        c(2.70, 2.70)
      )
    )
  )

  # ETAPA 8: Armazenar as geometrias em um objeto sf. A coluna `codigo` é o
  # identificador único utilizado pelas funções de extração.
  municipalities <- sf::st_sf(
    codigo = c("municipio_referencia", "municipio_borda"),
    municipio = c("Município de referência", "Município da borda"),
    geometry = sf::st_sfc(
      reference_geometry,
      border_geometry,
      crs = 4326
    )
  )

  # O retorno conjunto mantém todos os testes baseados nos mesmos dados de
  # entrada controlados.
  list(
    raster = climate_raster,
    municipalities = municipalities
  )
}


explicit_area_weighted_mean <- function(
    r,
    cell_weights,
    polygon_key,
    layer
) {
  # ETAPA 1: Manter apenas as interseções pertencentes ao município escolhido.
  # `polygon_key` tem intencionalmente um nome diferente da coluna `polygon_id`
  # para evitar ambiguidade na avaliação de nomes pelo data.table.
  polygon_weights <- cell_weights[
    cell_weights$polygon_id == polygon_key,
  ]

  # ETAPA 2: Ler o valor do mês selecionado somente nas células que interceptam
  # o município. A ordem das células é a mesma de `polygon_weights`.
  cell_values <- terra::extract(
    r[[layer]],
    polygon_weights$cell,
    raw = TRUE
  )[, 1]

  # ETAPA 3: Identificar as células com valores observados. Células ausentes não
  # podem contribuir para o numerador nem para o denominador da média.
  valid <- !is.na(cell_values)

  # Se todas as células forem ausentes, não há informação para o município
  # nesse mês. O resultado cientificamente correto é NA.
  if (!any(valid)) {
    return(NA_real_)
  }

  # ETAPA 4: `area_weight` já é o peso espacial completo de cada célula
  # (fração da célula contida no município multiplicada pela área física da
  # célula, em m2), calculado por make_polygon_cell_weights().
  explicit_weights <- polygon_weights$area_weight[valid]

  # ETAPA 5: Aplicar diretamente a equação. Como esta implementação não usa
  # Matrix::sparseMatrix(), ela fornece uma referência transparente para a
  # função otimizada do projeto.
  sum(cell_values[valid] * explicit_weights) /
    sum(explicit_weights)
}


testthat::test_that(
  "as médias pela matriz esparsa e pela fórmula explícita concordam",
  {
    # TESTE 1: Comparar duas implementações computacionais do mesmo estimador.
    # Diferenças inferiores a 1e-12 são tratadas como arredondamento numérico.
    fixture <- make_area_weighted_fixture()
    tolerance <- 1e-12

    # Calcular as interseções exatas e os pesos baseados em área física.
    cell_weights <- make_polygon_cell_weights(
      raster = fixture$raster,
      polygons = fixture$municipalities,
      polygon_ids = fixture$municipalities$codigo
    )

    # `sparse_result`: resultado da implementação otimizada por matriz esparsa.
    sparse_result <- calculate_area_weighted_mean(
      raster = fixture$raster[[1]],
      cell_weights = cell_weights,
      polygon_ids = fixture$municipalities$codigo,
      variable = "pr"
    )

    # `expected`: referência obtida aplicando a equação termo a termo.
    expected <- explicit_area_weighted_mean(
      r = fixture$raster,
      cell_weights = cell_weights,
      polygon_key = "municipio_referencia",
      layer = 1
    )

    # Selecionar somente o município de referência no resultado produzido.
    observed <- sparse_result$value[
      sparse_result$polygon_id == "municipio_referencia"
    ]

    # O teste passa se os métodos concordarem dentro da tolerância definida.
    testthat::expect_equal(
      observed,
      expected,
      tolerance = tolerance
    )
  }
)


testthat::test_that(
  "células parciais, valores ausentes e zeros são distinguidos",
  {
    # TESTE 2: Confirmar que os dados controlados realmente contêm os casos
    # especiais dos quais dependem as verificações seguintes. Esta checagem é
    # feita diretamente com terra::extract(exact = TRUE), independentemente do
    # formato interno de make_polygon_cell_weights().
    fixture <- make_area_weighted_fixture()

    reference_municipality <- fixture$municipalities[
      fixture$municipalities$codigo == "municipio_referencia",
    ]
    raw_intersections <- terra::extract(
      fixture$raster[[1]],
      terra::vect(reference_municipality),
      cells = TRUE,
      exact = TRUE
    )

    # Pelo menos uma interseção deve cobrir menos que uma célula completa.
    testthat::expect_true(
      any(
        raw_intersections$fraction > 0 &
          raw_intersections$fraction < 1
      )
    )

    # A célula 5 intercepta o município e seu valor no raster é NA.
    testthat::expect_true(5 %in% raw_intersections$cell)
    testthat::expect_true(
      is.na(terra::values(fixture$raster[[1]])[5, 1])
    )

    # A célula 4 também intercepta o município, mas contém zero observado.
    # Esse zero não pode ser confundido com o NA da célula 5.
    testthat::expect_true(4 %in% raw_intersections$cell)
    testthat::expect_equal(
      unname(terra::values(fixture$raster[[1]])[4, 1]),
      0
    )

    # Apesar do NA, as células válidas restantes permitem calcular uma média.
    cell_weights <- make_polygon_cell_weights(
      raster = fixture$raster,
      polygons = fixture$municipalities,
      polygon_ids = fixture$municipalities$codigo
    )
    expected_without_na <- explicit_area_weighted_mean(
      r = fixture$raster,
      cell_weights = cell_weights,
      polygon_key = "municipio_referencia",
      layer = 1
    )

    testthat::expect_true(is.finite(expected_without_na))
  }
)


testthat::test_that(
  "camadas somente com NA e somente com zero têm resultados distintos",
  {
    # TESTE 3: Verificar a diferença fundamental entre informação ausente e uma
    # observação meteorológica válida igual a zero.
    fixture <- make_area_weighted_fixture()

    cell_weights <- make_polygon_cell_weights(
      raster = fixture$raster,
      polygons = fixture$municipalities,
      polygon_ids = fixture$municipalities$codigo
    )

    # Calcular simultaneamente os dois municípios e as três camadas mensais.
    result <- calculate_area_weighted_mean(
      raster = fixture$raster,
      cell_weights = cell_weights,
      polygon_ids = fixture$municipalities$codigo,
      variable = "pr"
    )

    # Fevereiro é a camada composta inteiramente por valores NA.
    all_missing <- result$value[
      result$date == as.Date("2020-02-01")
    ]

    # Março é a camada composta inteiramente por zeros observados.
    observed_zero <- result$value[
      result$date == as.Date("2020-03-01")
    ]

    # Os dois municípios devem retornar NA em fevereiro e zero em março.
    testthat::expect_true(all(is.na(all_missing)))
    testthat::expect_true(all(observed_zero == 0))
  }
)


testthat::test_that(
  "um município pequeno na borda da grade é calculado corretamente",
  {
    # TESTE 4: Verificar um polígono menor que uma célula na borda da grade.
    fixture <- make_area_weighted_fixture()
    tolerance <- 1e-12

    cell_weights <- make_polygon_cell_weights(
      raster = fixture$raster,
      polygons = fixture$municipalities,
      polygon_ids = fixture$municipalities$codigo
    )

    # Isolar as interseções do município pequeno situado na borda.
    border_weights <- cell_weights[
      cell_weights$polygon_id == "municipio_borda",
    ]

    # Ele deve interceptar pelo menos uma célula.
    testthat::expect_gt(nrow(border_weights), 0)

    # Calcular separadamente o resultado otimizado e a referência explícita.
    sparse_result <- calculate_area_weighted_mean(
      raster = fixture$raster[[1]],
      cell_weights = cell_weights,
      polygon_ids = fixture$municipalities$codigo,
      variable = "pr"
    )

    expected <- explicit_area_weighted_mean(
      r = fixture$raster,
      cell_weights = cell_weights,
      polygon_key = "municipio_borda",
      layer = 1
    )

    observed <- sparse_result$value[
      sparse_result$polygon_id == "municipio_borda"
    ]

    # Os dois cálculos devem concordar dentro da mesma tolerância numérica.
    testthat::expect_equal(
      observed,
      expected,
      tolerance = tolerance
    )
  }
)


testthat::test_that(
  "a função de alto nível preserva os resultados validados",
  {
    # TESTE 5: Verificar a função de alto nível extract_area_weighted_mean(),
    # que recalcula os pesos internamente e transforma a tabela para formato
    # largo.
    fixture <- make_area_weighted_fixture()

    municipalities <- fixture$municipalities
    names(municipalities)[names(municipalities) == "codigo"] <- "polygon_id"

    # A lista deve ser nomeada, pois seus nomes viram variáveis na saída.
    wrapper_result <- extract_area_weighted_mean(
      rasters = list(pr = fixture$raster),
      polygons = municipalities,
      id_col = "polygon_id"
    )

    # O resultado largo deve conter identificadores, datas e uma coluna `pr`.
    testthat::expect_named(
      wrapper_result,
      c("polygon_id", "date", "pr")
    )

    # Linhas esperadas = número de municípios multiplicado pelo número de meses.
    testthat::expect_equal(
      nrow(wrapper_result),
      nrow(fixture$municipalities) * terra::nlyr(fixture$raster)
    )

    # A camada de fevereiro deve continuar NA após a transformação para largo.
    testthat::expect_true(
      all(
        is.na(
          wrapper_result$pr[
            wrapper_result$date == as.Date("2020-02-01")
          ]
        )
      )
    )
  }
)
