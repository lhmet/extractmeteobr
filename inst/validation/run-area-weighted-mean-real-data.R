# Executar depois que `filled_monthly_rasters` (ou `monthly_rasters`) e
# `municipalities` estiverem disponíveis, por exemplo como saída de
# run_meteo_pipeline(..., return_intermediate = TRUE). Carregue o pacote com
# devtools::load_all() antes de rodar este script, pois
# validate-area-weighted-mean-real-data.R usa funções internas não
# exportadas do pacote.

source(
  here::here(
    "inst/validation/validate-area-weighted-mean-real-data.R"
  )
)

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
