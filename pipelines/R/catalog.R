# Gera datapackage.json por dataset/versão + catalog.json raiz, lendo a
# proveniência embutida (climasus_meta) direto do schema Arrow de cada Parquet
# Gold. Falha (não avisa) se algum Gold não tiver a chave — é o jeito da
# plataforma garantir que ninguém publicou um dataset "mudo".

# Documentação curada por dataset — título, descrição rica, descrição por
# coluna e o trecho de pipeline que gera o dado (mostrado no card de detalhe
# do Catálogo, CatalogDetail.tsx). Dataset sem entrada aqui cai no fallback
# genérico em build_datapackage() — não quebra ao publicar um dataset novo
# antes de documentá-lo, só fica menos informativo até alguém preencher.
DATASET_DOCS <- list(
  dim_station = list(
    title = "Estações Meteorológicas (INMET)",
    description = paste(
      "Dimensão de estações meteorológicas automáticas do INMET usadas como",
      "fonte de clima observacional em todo o pipeline. Uma linha por estação:",
      "código, nome e coordenadas (WGS84). Alimenta a camada deck.gl de",
      "estações no mapa do atlas e é a base do pareamento espacial",
      "estação↔município (vizinho mais próximo) feito por",
      "climasus4r::sus_climate_aggregate()."
    ),
    columns = list(
      station_code = "Código da estação automática INMET (ex. A925) — chave",
      station_name = "Nome da estação (geralmente o município-sede)",
      latitude      = "Latitude da estação, graus decimais (WGS84)",
      longitude     = "Longitude da estação, graus decimais (WGS84)"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gold.R",
        fn   = "make_dim_station()",
        snippet = paste(
          "station_meta_path <- system.file(\"data_4r\", \"station_meta.parquet\", package = \"climasus4r\")",
          "stations <- arrow::read_parquet(station_meta_path) |>",
          "  dplyr::filter(federal_unit == cfg$uf) |>",
          "  dplyr::transmute(station_code, station_name,",
          "                    latitude = as.double(latitude), longitude = as.double(longitude))",
          "climasus4r::write_parquet_climasus(stations, out_path)",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  health_climate_daily = list(
    title = "Saúde & Clima Diário",
    description = paste(
      "Mart principal do atlas — série diária de óbitos em grupos de causa",
      "climaticamente sensível (CID-10: total, respiratório, circulatório),",
      "pareada à variável climática do dia, por município do Brasil,",
      "2018–2023. Óbitos vêm do SIM-DO (DATASUS, via microdatasus), agregados",
      "por dia/município/grupo de causa; clima vem de estações automáticas",
      "INMET (temporal_strategy='exact': valor do próprio dia, pareamento",
      "por estação mais próxima), com a série de temperatura preenchida por",
      "imputação XGBoost station-wise (sus_climate_fill_inmet()) antes do",
      "pareamento, reduzindo a fração de dado climático ausente."
    ),
    columns = list(
      code_muni    = "Código IBGE do município, 7 dígitos — chave",
      name_muni    = "Nome do município",
      date         = "Dia (ISO YYYY-MM-DD) — chave",
      deaths_total = "Óbitos totais nos grupos CID climate-sensitive (SIM-DO)",
      deaths_resp  = "Óbitos do grupo respiratório (CID-10)",
      deaths_circ  = "Óbitos do grupo circulatório (CID-10)",
      tmean        = "Temperatura média diária (°C), estação INMET mais próxima",
      tmax         = "Temperatura máxima diária (°C)",
      tmin         = "Temperatura mínima diária (°C)",
      precip       = "Precipitação diária (mm)",
      rh           = "Umidade relativa média diária (%)"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gold.R",
        fn   = "make_health_climate_mart()",
        snippet = paste(
          "joined <- climasus4r::sus_climate_aggregate(",
          "  health_data       = health_climasus,  # óbitos SIM-DO por município x dia (sf)",
          "  climate_data      = silver_inmet,      # série INMET já preenchida",
          "  climate_var       = c(\"tair_dry_bulb_c\", \"tair_max_c\", \"tair_min_c\",",
          "                        \"rainfall_mm\", \"rh_mean_porc\"),",
          "  time_unit         = \"day\",",
          "  temporal_strategy = \"exact\"",
          ")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  heatwave_events = list(
    title = "Eventos de Onda de Calor",
    description = paste(
      "Catálogo de eventos de onda de calor detectados na série diária de",
      "temperatura de cada estação INMET, por três metodologias (OMS, OMM,",
      "INMET — thresholds e janelas de baseline distintos), via",
      "climasus4r::sus_climate_compute_heatwaves(). Grão: evento x estação x",
      "método — cada linha é um episódio contíguo de temperatura acima do",
      "limiar da estação, com duração, anomalia, severidade e Excess Heat",
      "Factor (EHF)."
    ),
    columns = list(
      event_id           = "Identificador único do evento — chave",
      station_code       = "Estação INMET onde o evento foi detectado",
      station_name       = "Nome da estação",
      method             = "Metodologia de detecção: WHO, WMO ou INMET (thresholds/baseline distintos)",
      start_date         = "Data de início do evento",
      end_date           = "Data de fim do evento",
      duration_days      = "Duração do evento em dias",
      temp_mean          = "Temperatura média durante o evento (°C)",
      temp_peak          = "Temperatura de pico durante o evento (°C)",
      anomaly_mean       = "Anomalia média em relação ao baseline da estação (°C)",
      anomaly_cumulative = "Anomalia acumulada do evento (°C·dia)",
      severity_index     = "Índice de severidade (combina duração e intensidade)",
      ehf_peak           = "Excess Heat Factor (EHF) de pico durante o evento",
      ehf_mean           = "Excess Heat Factor (EHF) médio durante o evento",
      intensity_class    = "Classe de intensidade do evento (ex. low/severe/extreme)",
      region             = "Região da estação",
      federal_unit       = "UF da estação",
      zona_climatica     = "Zona climática da estação",
      latitude           = "Latitude da estação (WGS84)",
      longitude          = "Longitude da estação (WGS84)"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gold.R",
        fn   = "make_heatwave_events()",
        snippet = paste(
          "hw <- climasus4r::sus_climate_compute_heatwaves(",
          "  bronze_inmet,",
          "  method         = c(\"WHO\", \"WMO\", \"INMET\"),",
          "  baseline_start = NULL,  # usa o período disponível por estação",
          "  baseline_end   = NULL,",
          "  percentile     = 90",
          ")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  health_climate_distributed_lag = list(
    title = "Saúde & Clima — Matriz de Defasagem",
    description = paste(
      "Insumo de modelagem (Fase 2b): mesma cobertura de health_climate_daily,",
      "mas com temporal_strategy='distributed_lag' — cada linha carrega o",
      "histórico de exposição climática dos últimos 21 dias (matriz de lag),",
      "não só o valor do dia. Existe especificamente para alimentar",
      "modelagem de risco defasado (DLNM ou outra); não é consumido",
      "diretamente pelos gráficos do atlas."
    ),
    columns = list(
      code_muni    = "Código IBGE do município, 7 dígitos — chave",
      name_muni    = "Nome do município",
      date         = "Dia (ISO YYYY-MM-DD) — chave",
      deaths_total = "Óbitos totais nos grupos CID climate-sensitive",
      deaths_resp  = "Óbitos do grupo respiratório",
      deaths_circ  = "Óbitos do grupo circulatório",
      tair_dry_bulb_c = "Temperatura média do dia corrente (°C) — idêntica a tair_dry_bulb_c_lag0",
      tair_dry_bulb_c_lag0  = "Temperatura média (°C) do próprio dia (lag 0)",
      tair_dry_bulb_c_lag1  = "Temperatura média (°C) 1 dia antes",
      tair_dry_bulb_c_lag7  = "Temperatura média (°C) 7 dias antes",
      tair_dry_bulb_c_lag14 = "Temperatura média (°C) 14 dias antes",
      tair_dry_bulb_c_lag21 = "Temperatura média (°C) 21 dias antes (lag máximo, config dlnm.lag_days)"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/dlnm.R",
        fn   = "make_distributed_lag_mart()",
        snippet = paste(
          "dl <- climasus4r::sus_climate_aggregate(",
          "  health_data       = health_climasus,",
          "  climate_data      = silver_inmet,",
          "  climate_var       = cfg$dlnm$climate_var,  # \"tair_dry_bulb_c\"",
          "  time_unit         = \"day\",",
          "  temporal_strategy = \"distributed_lag\",",
          "  lag_days          = cfg$dlnm$lag_days      # 21",
          ")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  dlnm_exposure_response = list(
    title = "DLNM — Curva Exposição-Resposta",
    description = paste(
      "Saída de um DLNM (Distributed Lag Non-linear Model,",
      "climasus4r::sus_mod_dlnm()) ajustado por UF a partir de",
      "health_climate_distributed_lag. Grão UF x ponto de grade de exposição",
      "(~100 pontos, do 1º ao 99º percentil de temperatura observada): curva",
      "de risco relativo cumulativo (todos os 21 lags somados) em função da",
      "temperatura, centrada na mediana (RR=1). Consumida pelo gráfico",
      "'overall' do indicador Relative Risk (DLNM) em Explore.tsx.",
      "Limitação por desenho: 1 modelo por UF inteira mistura municípios",
      "com climas/populações distintos — tratar como triagem regional, não",
      "risco município-específico; ver disp_ratio/has_autocorr abaixo."
    ),
    columns = list(
      uf           = "Unidade federativa — chave, 1 modelo por UF",
      disp_ratio   = "Razão de dispersão do GLM quasi-Poisson (>1 = sobredispersão)",
      has_autocorr = "TRUE = autocorrelação residual significativa (teste de Ljung-Box) — tratar RR como indicativo, não estimativa confiável",
      exposure     = "Temperatura (°C) do ponto de grade de exposição",
      rr           = "Risco relativo cumulativo (todos os lags) vs. mediana da UF",
      lo           = "Limite inferior do IC 95%",
      hi           = "Limite superior do IC 95%",
      pct          = "Percentil de temperatura mais próximo deste ponto (25/50/75/90/95/99); NULL nos demais pontos de grade"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/dlnm.R",
        fn   = "make_dlnm_relative_risk() / .dlnm_exposure_response_full_tbl()",
        snippet = paste(
          "fit <- climasus4r::sus_mod_dlnm(",
          "  df          = distributed_lag_mart,",
          "  outcome_col = \"deaths_total\",",
          "  climate_col = \"tair_dry_bulb_c\",",
          "  lag_max     = 21,",
          "  family      = \"quasipoisson\"",
          ")",
          "# curva fina (100 pontos) a partir de fit$pred$predvar/allRRfit,",
          "# mesma curva que climasus4r:::.plot_dlnm_overall() desenha em R",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  dlnm_lag_response = list(
    title = "DLNM — Curva de Defasagem",
    description = paste(
      "Saída do mesmo DLNM por UF (ver dlnm_exposure_response), grão UF x",
      "lag (dia de defasagem, 0 a 21): efeito isolado de cada dia de",
      "defasagem sobre o risco relativo, avaliado na temperatura do",
      "percentil 75 observado na UF. Consumida pelo gráfico 'lag' do",
      "indicador Relative Risk (DLNM) em Explore.tsx."
    ),
    columns = list(
      uf           = "Unidade federativa — chave",
      disp_ratio   = "Razão de dispersão do GLM quasi-Poisson",
      has_autocorr = "TRUE = autocorrelação residual significativa (Ljung-Box)",
      lag          = "Dia de defasagem (0 a dlnm.lag_days, default 21)",
      rr           = "Risco relativo isolado daquele dia de defasagem",
      lo           = "Limite inferior do IC 95%",
      hi           = "Limite superior do IC 95%",
      rr_cum       = "Risco relativo acumulado do lag 0 até este lag"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/dlnm.R",
        fn   = "make_dlnm_relative_risk() -> fit$lag_response",
        snippet = paste(
          "fit <- climasus4r::sus_mod_dlnm(df = distributed_lag_mart,",
          "                                outcome_col = \"deaths_total\",",
          "                                climate_col = \"tair_dry_bulb_c\",",
          "                                lag_max = 21, family = \"quasipoisson\")",
          "write_dlnm_dataset(fit$lag_response, \"dlnm_lag_response\")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  dlnm_surface = list(
    title = "DLNM — Superfície Exposição x Lag",
    description = paste(
      "Saída do mesmo DLNM por UF (ver dlnm_exposure_response), grão UF x",
      "exposição x lag (~100 x 22 pontos): superfície bidimensional completa",
      "do risco relativo (sem IC — só o ponto estimado), para o heatmap",
      "'onde na grade temperatura x tempo o efeito é mais forte'. Consumida",
      "pelo gráfico 'surface' do indicador Relative Risk (DLNM) em",
      "Explore.tsx."
    ),
    columns = list(
      uf           = "Unidade federativa — chave",
      disp_ratio   = "Razão de dispersão do GLM quasi-Poisson",
      has_autocorr = "TRUE = autocorrelação residual significativa (Ljung-Box)",
      exposure     = "Temperatura (°C) do ponto de grade",
      lag          = "Dia de defasagem",
      rr           = "Risco relativo estimado nesse ponto (exposição, lag) — sem IC"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/dlnm.R",
        fn   = "make_dlnm_relative_risk() / .dlnm_surface_tbl()",
        snippet = paste(
          "# achata fit$pred$matRRfit (matriz exposição x lag) em formato longo",
          "lag_seq <- seq(fit$pred$lag[1], fit$pred$lag[2])",
          "exp_vec <- fit$pred$predvar",
          "tibble::tibble(exposure = rep(exp_vec, times = length(lag_seq)),",
          "               lag      = rep(lag_seq, each = length(exp_vec)),",
          "               rr       = as.vector(fit$pred$matRRfit))",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  env_era5_daily = list(
    title = "Clima em Grade — ERA5-Land",
    description = paste(
      "Dataset Gold complementar (Fase 3, trilha A): temperatura e",
      "precipitação diária por município a partir da reanálise ERA5-Land",
      "(ECMWF), agregada por município via exactextractr (média ponderada",
      "por área) dentro de climasus4r::sus_grid_era5() — o pipeline nunca",
      "lida com o raster/NetCDF bruto. Complementa o INMET em áreas de baixa",
      "densidade de estações; não é misturado ao mart health_climate_daily",
      "(ver climasus4r::sus_grid_join() para combinar por fora, se preciso)."
    ),
    columns = list(
      code_muni       = "Código IBGE do município, 7 dígitos — chave",
      date            = "Dia (ISO YYYY-MM-DD) — chave",
      tair_dry_bulb_c = "Temperatura média diária (°C), ERA5-Land agregada por município",
      rainfall_mm     = "Precipitação diária (mm), ERA5-Land agregada por município"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gridded.R",
        fn   = "get_gridded_era5()",
        snippet = paste(
          "climasus4r::sus_grid_era5(",
          "  years          = cfg$years,       # 2018:2023",
          "  municipalities = muni_sf           # polígonos reais (geobr), não centróide",
          ")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  env_chirps_daily = list(
    title = "Clima em Grade — CHIRPS",
    description = paste(
      "Dataset Gold complementar (Fase 3, trilha A): precipitação diária",
      "por município a partir do CHIRPS v2.0 (Climate Hazards Group,",
      "satélite + estações, ~5km), agregada por município via",
      "exactextractr dentro de climasus4r::sus_grid_chirps(). Fonte de",
      "chuva de alta resolução espacial onde o INMET tem estação esparsa —",
      "relevante para leptospirose, doenças diarreicas e dengue."
    ),
    columns = list(
      code_muni          = "Código IBGE do município, 7 dígitos — chave",
      date               = "Dia (ISO YYYY-MM-DD) — chave",
      rainfall_chirps_mm = "Precipitação diária (mm), CHIRPS v2.0 agregada por município"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gridded.R",
        fn   = "get_gridded_chirps()",
        snippet = paste(
          "climasus4r::sus_grid_chirps(",
          "  years          = cfg$years,       # 2018:2023",
          "  municipalities = muni_sf           # polígonos reais (geobr)",
          ")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  env_prodes_daily = list(
    title = "Desmatamento — PRODES",
    description = paste(
      "Dataset Gold complementar (Fase 3, trilha A): desmatamento anual por",
      "município a partir do PRODES/INPE (TerraBrasilis WFS), interseção",
      "espacial de polígonos de desmatamento com o polígono do município via",
      "climasus4r::sus_grid_prodes(), nos 6 biomas monitorados. Relevante",
      "como exposição para malária de fronteira (SINAN), dengue,",
      "leishmaniose e doença respiratória por queima de biomassa."
    ),
    columns = list(
      code_muni            = "Código IBGE do município, 7 dígitos — chave",
      year                 = "Ano PRODES (agosto do ano-1 a julho do ano)",
      date                 = "1º de janeiro do ano PRODES (convenção de publicação)",
      deforested_area_km2  = "Área total de desmatamento (km²) intersectando o município, no ano",
      n_patches            = "Número de manchas de desmatamento distintas intersectando o município",
      biome                = "Bioma PRODES de origem (Amazon, Cerrado, MataAtlantica, Caatinga, Pampa, Pantanal)"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gridded.R",
        fn   = "get_gridded_prodes()",
        snippet = paste(
          "climasus4r::sus_grid_prodes(",
          "  years          = cfg$years,       # 2018:2023",
          "  uf             = cfg$uf,",
          "  municipalities = muni_sf           # polígonos reais (geobr)",
          "  # sem filtro CQL por estado — download nacional por bioma/ano,",
          "  # a interseção espacial com municipalities já recorta por UF",
          ")",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  ),
  env_pollution_cams_daily = list(
    title = "Poluição do Ar — CAMS",
    description = paste(
      "Dataset Gold complementar (Fase 3, trilha A): concentração diária de",
      "material particulado (PM2.5, PM10) por município a partir da",
      "reanálise CAMS (Copernicus Atmosphere Monitoring Service), via",
      "climasus4r::sus_grid_pollution_cams() — dataset já vem por",
      "município (sem etapa de zonal-stat local). Relevante como exposição",
      "para doença respiratória e cardiovascular."
    ),
    columns = list(
      code_muni = "Código IBGE do município, 7 dígitos — chave",
      date      = "Dia (ISO YYYY-MM-DD) — chave",
      pm25_mean = "Concentração média diária de PM2.5 (µg/m³), reanálise CAMS",
      pm10_mean = "Concentração média diária de PM10 (µg/m³), reanálise CAMS"
    ),
    generator = list(
      r = list(
        path = "pipelines/R/gridded.R",
        fn   = "get_gridded_pollution_cams()",
        snippet = paste(
          "climasus4r::sus_grid_pollution_cams(",
          "  years = cfg$years   # 2018:2023 — já devolve por município,",
          ")                     # sem precisar de `municipalities`",
          sep = "\n"
        )
      ),
      python = list(available = FALSE)
    )
  )
)

find_gold_files <- function(public_dir) {
  # Dois formatos aceitos: particionado por qualquer chave Hive
  # (uf=RO, regiao=Nordeste, municipio=3550308, ...) ou nacional/sem
  # partição (data.parquet direto em v{version}/). dataset_info_from_path()
  # decide qual é qual pelo nome do penúltimo segmento do path.
  c(
    Sys.glob(file.path(public_dir, "gold", "*", "v*", "*", "data.parquet")),
    Sys.glob(file.path(public_dir, "gold", "*", "v*", "data.parquet"))
  )
}

read_climasus_meta <- function(path) {
  ds <- arrow::open_dataset(path)
  meta_json <- ds$schema$metadata[["climasus_meta"]]
  if (is.null(meta_json)) {
    cli::cli_abort("Parquet Gold sem climasus_meta (proveniência ausente): {.path {path}}")
  }
  jsonlite::fromJSON(meta_json, simplifyVector = TRUE)
}

resource_path_for <- function(rel_path, ext) {
  sub("data\\.parquet$", ext, rel_path)
}

build_resource_entries <- function(path, rel_path, ds, docs) {
  base_schema <- list(fields = purrr::map(ds$schema$fields, function(field) {
    list(
      name        = field$name,
      type        = field$type$ToString(),
      description = if (!is.null(docs)) docs$columns[[field$name]] %||% "" else ""
    )
  }))

  resources <- list(list(
    name   = tools::file_path_sans_ext(basename(rel_path)),
    path   = rel_path,
    format = "parquet",
    schema = base_schema
  ))

  sibling_formats <- list(
    list(ext = "data.csv.zip", format = "csv")
  )
  for (spec in sibling_formats) {
    sibling_path <- resource_path_for(rel_path, spec$ext)
    # Checar no disco exige o caminho absoluto (`path`) — `rel_path` é
    # relativo a public_dir, não ao cwd, e sempre resolvia para inexistente.
    if (file.exists(file.path(dirname(path), basename(sibling_path)))) {
      resources[[length(resources) + 1L]] <- list(
        name   = tools::file_path_sans_ext(basename(sibling_path)),
        path   = sibling_path,
        format = spec$format,
        schema = base_schema
      )
    }
  }

  resources
}

dataset_info_from_path <- function(path) {
  # Duas formas:
  #   .../gold/{dataset}/v{version}/{key}={value}/data.parquet  (particionado)
  #   .../gold/{dataset}/v{version}/data.parquet                (nacional, sem partição)
  # O penúltimo segmento é a versão ("v1.0.0") no caso sem partição, ou o
  # diretório "{key}={value}" no caso particionado — distinguimos pelo prefixo "v".
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  n <- length(parts)
  if (grepl("^v[0-9]", parts[n - 1])) {
    list(dataset = parts[n - 2], version = sub("^v", "", parts[n - 1]), key = "all", value = "all")
  } else {
    kv <- strsplit(parts[n - 1], "=", fixed = TRUE)[[1]]
    list(
      dataset = parts[n - 3],
      version = sub("^v", "", parts[n - 2]),
      key     = kv[1],
      value   = if (length(kv) > 1) kv[2] else NA_character_
    )
  }
}

build_datapackage <- function(path, rel_path, meta, info) {
  ds   <- arrow::open_dataset(path)
  docs <- DATASET_DOCS[[info$dataset]] # NULL se o dataset ainda não tem entrada curada

  description <- if (!is.null(docs)) {
    docs$description
  } else {
    sprintf("Gold dataset '%s', %s=%s. Ver docs/DATA_MODEL.md.", info$dataset, info$key, info$value)
  }

  list(
    name        = info$dataset,
    title       = if (!is.null(docs)) docs$title else info$dataset,
    version     = info$version,
    description = description,
    licenses    = list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/")),
    resources   = build_resource_entries(path, rel_path, ds, docs),
    generator     = if (!is.null(docs)) docs$generator else list(
      r = list(available = FALSE), python = list(available = FALSE)
    ),
    climasus_meta = meta,
    rows          = tryCatch(nrow(ds), error = function(e) NA_integer_)
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Constrói catalog.json raiz + 1 datapackage.json por dataset Gold encontrado.
#' @param public_dir caminho para data/public
build_catalog <- function(public_dir) {
  files <- find_gold_files(public_dir)
  if (length(files) == 0) {
    cli::cli_abort("Nenhum Parquet Gold encontrado em {.path {public_dir}/gold}")
  }

  # Cada dataset Gold é Hive-particionado por uma chave arbitrária (uf=RO,
  # regiao=Nordeste, ...) ou nacional/sem partição (key="all", value="all",
  # um arquivo só). Um dataset com N partições gera N arquivos data.parquet
  # (mesma versão). Guardamos cada partição em `partitions` (fonte de
  # verdade) para não perder rows/path das partições "anteriores" quando há
  # mais de uma — só sobrescrever path/rows a cada iteração (como antes)
  # fazia catalog.json mentir o total nacional pelo total da última partição
  # processada.
  entries <- list()
  for (path in files) {
    info <- dataset_info_from_path(path)
    meta <- read_climasus_meta(path) # aborta aqui se a chave estiver ausente
    rel_path <- sub(paste0("^", public_dir, "/?"), "", path)
    dp <- build_datapackage(path, rel_path, meta, info)

    dp_path <- file.path(dirname(path), "datapackage.json")
    jsonlite::write_json(dp, dp_path, auto_unbox = TRUE, pretty = TRUE)

    dataset_key <- info$dataset
    if (is.null(entries[[dataset_key]])) {
      entries[[dataset_key]] <- list(versions = character(0), partitions = list(), synthetic = FALSE)
    }
    entries[[dataset_key]]$versions <- union(entries[[dataset_key]]$versions, info$version)
    entries[[dataset_key]]$partitions[[length(entries[[dataset_key]]$partitions) + 1L]] <- list(
      version = info$version, key = info$key, value = info$value, path = rel_path, rows = dp$rows,
      synthetic = isTRUE(meta$user$synthetic)
    )
  }

  datasets <- lapply(names(entries), function(dataset_key) {
    e <- entries[[dataset_key]]
    latest <- sort(e$versions, decreasing = TRUE)[1]
    latest_parts <- Filter(function(p) p$version == latest, e$partitions)
    latest_parts <- latest_parts[order(vapply(latest_parts, `[[`, character(1), "value"))]

    list(
      name      = dataset_key,
      latest    = paste0("v", latest),
      versions  = paste0("v", sort(e$versions)),
      # Derivado das partições da versão `latest` — não do último arquivo do
      # glob, que podia ser de outra versão (ex. v0.1.0 sintético residual).
      synthetic = any(vapply(latest_parts, function(p) isTRUE(p$synthetic), logical(1))),
      # path/rows = só a 1ª partição (ordem alfabética do valor) e a SOMA de
      # linhas entre todas — compatível com o caso de 1 partição só.
      # `partitions` é o que qualquer leitor multi-partição (ex. frontend)
      # deve usar de fato: não há listagem de diretório em hosting
      # estático/HTTP range, então cada partição precisa da sua própria URL
      # explícita.
      path       = latest_parts[[1]]$path,
      rows       = sum(vapply(latest_parts, `[[`, numeric(1), "rows"), na.rm = TRUE),
      partitions = lapply(latest_parts, function(p) list(key = p$key, value = p$value, path = p$path, rows = p$rows))
    )
  })

  catalog <- list(datasets = datasets)
  catalog_path <- file.path(public_dir, "catalog.json")
  jsonlite::write_json(catalog, catalog_path, auto_unbox = TRUE, pretty = TRUE)

  cli::cli_alert_success("Catálogo gerado: {catalog_path} ({length(datasets)} dataset(s))")
  catalog_path
}
