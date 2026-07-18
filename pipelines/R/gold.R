# Camada Gold — analytics-ready, servida ao portal. Duas saídas nesta fase:
#   - health_climate_daily (mart, schema em docs/DATA_MODEL.md)
#   - heatwave_events (catálogo de eventos, grão evento x estação x método)
# Regra: sempre write_parquet_climasus(); nunca sus_as_arrow()/sus_as_duckdb().

# Espelha TODOS os grupos de resolve_geo_col() (R/sus_data_aggregate.R) —
# não só "residencia". Para SIM (mortalidade), o pacote prioriza
# "ocorrencia" (município de óbito) sobre "residencia"; outros sistemas
# priorizam diferente. sus_data_aggregate() já escolheu e manteve UMA
# coluna geo — aqui só precisamos reconhecer qual foi, não replicar a
# prioridade.
.GEO_COL_CANDIDATES <- c(
  "codigo_municipio_residencia", "residence_municipality_code",
  "municipio_residencia_paciente_sp", "CODMUNRES", "MUNI_RES",
  "codigo_municipio_ocorrencia", "codigo_municipio_ocurrencia",
  "occurrence_municipality_code", "codigo_municipio_notificacao",
  "codigo_municipio_notificacion", "notification_municipality_code",
  "codigo_municipio", "municipality_code", "codigo_municipio_paciente",
  "patient_municipality_code"
)

resolve_geo_col_name <- function(df) {
  found <- intersect(.GEO_COL_CANDIDATES, names(df))
  if (length(found) == 0) {
    cli::cli_abort("Nenhuma coluna de município encontrada em {.val {names(df)}}")
  }
  found[1]
}

#' Agrega óbitos por município x dia, em 3 recortes (total/resp/circ), e junta.
# backend="tibble" em filter_cid/aggregate pelo mesmo motivo do silver.R:
# cada função tem seu próprio default "arrow" (lazy), independente do
# backend do objeto de entrada.
make_health_daily <- function(silver_sim, cfg) {
  agg_group <- function(disease_group) {
    df <- silver_sim |>
      climasus4r::sus_data_filter_cid(disease_group = disease_group, backend = "tibble") |>
      climasus4r::sus_data_aggregate(
        time_unit      = cfg$health$time_unit,
        fun            = "count",
        complete_dates = TRUE,
        lang           = "en", # garante nome de coluna "n_deaths" (pt default daria "n_obitos")
        backend        = "tibble"
      )
    geo_col <- resolve_geo_col_name(df)
    df |>
      dplyr::rename(code_muni = dplyr::all_of(geo_col)) |>
      dplyr::mutate(code_muni = as.integer(code_muni)) |>
      dplyr::select(code_muni, date, n_deaths)
  }

  total <- agg_group(cfg$health$disease_group) |> dplyr::rename(deaths_total = n_deaths)
  resp  <- agg_group("respiratory")            |> dplyr::rename(deaths_resp  = n_deaths)
  circ  <- agg_group("cardiovascular")         |> dplyr::rename(deaths_circ  = n_deaths)

  total |>
    dplyr::left_join(resp, by = c("code_muni", "date")) |>
    dplyr::left_join(circ, by = c("code_muni", "date")) |>
    dplyr::mutate(
      deaths_resp = dplyr::coalesce(deaths_resp, 0L),
      deaths_circ = dplyr::coalesce(deaths_circ, 0L)
    )
}

#' Dimensão de municípios com geometria PONTO (lon/lat de municipio_meta.parquet,
#' embutido no pacote — zero rede). sus_climate_aggregate() exige que
#' `health_data` seja um sf com `code_muni` (usa-o como `spatial_obj` para o
#' pareamento estação<->município via st_nearest_feature); como o pacote não
#' embute polígonos, um ponto no centróide já é suficiente para essa distância
#' — é exatamente o que um polígono reduziria a `st_point_on_surface()` mesmo
#' assim. Trocar por polígonos reais (geobr, via sus_spatial_join) é a
#' evolução natural quando o pipeline rodar com rede disponível.
#' `code_muni_datasus` = código IBGE de 6 dígitos SEM o dígito verificador —
#' é o que o DATASUS grava em CODMUNRES/CODMUNOCOR (`floor(ibge7 / 10)`,
#' relação 1:1 porque o 7º dígito é calculado a partir dos outros 6). É essa
#' coluna que casa com `resolve_geo_col_name()` em `make_health_daily()`,
#' NÃO o código IBGE de 7 dígitos publicado no Gold.
muni_points_ro <- function(cfg) {
  muni_meta_path <- system.file("data_4r", "municipio_meta.parquet", package = "climasus4r")
  muni <- arrow::read_parquet(muni_meta_path) |>
    dplyr::filter(uf_code == cfg$uf) |>
    dplyr::transmute(
      code_muni = as.integer(municipio),
      code_muni_datasus = code_muni %/% 10L,
      name_muni = name, lon, lat
    )
  sf::st_as_sf(muni, coords = c("lon", "lat"), crs = 4674, remove = FALSE)
}

#' Junta o agregado de saúde (município-dia, código DATASUS) à geometria de
#' município e devolve um climasus_df sf pronto para sus_climate_aggregate()
#' — passo comum a QUALQUER temporal_strategy (extraído daqui porque
#' pipelines/R/dlnm.R precisa do mesmo pareamento espacial para gerar a
#' série "distributed_lag", não só a "exact" do mart publicado).
build_health_sf <- function(health_daily, cfg) {
  muni_sf <- muni_points_ro(cfg) |> dplyr::select(code_muni_datasus, code_muni, name_muni)

  # health_daily$code_muni veio de resolve_geo_col_name() == código DATASUS
  # de 6 dígitos (sem dígito verificador) — não é ainda o code_muni IBGE de
  # 7 dígitos do contrato (docs/DATA_MODEL.md). O join abaixo troca pelo
  # código IBGE correto via muni_sf$code_muni_datasus.
  #
  # Dados reais do DATASUS também podem trazer óbitos com código de FORA da
  # UF (ex.: transferência hospitalar para outro estado) — sem geometria em
  # muni_sf, essas linhas quebram o pareamento espacial do climasus4r
  # ("missing value where TRUE/FALSE needed"). Descartamos aqui, com aviso.
  health_daily <- health_daily |> dplyr::rename(code_muni_datasus = code_muni)
  n_before <- nrow(health_daily)
  health_daily <- health_daily |>
    dplyr::filter(code_muni_datasus %in% muni_sf$code_muni_datasus)
  n_dropped <- n_before - nrow(health_daily)
  if (n_dropped > 0) {
    cli::cli_alert_warning(
      "{n_dropped} linha(s) de health_daily com código fora de uf={cfg$uf} descartada(s) antes do pareamento espacial."
    )
  }

  # left_join com x = tibble comum descarta a classe sf de `muni_sf`; a coluna
  # de geometria (sfc) sobrevive como list-column, então sf::st_as_sf()
  # restaura o objeto espacial depois do join.
  health_sf <- health_daily |>
    dplyr::left_join(muni_sf, by = "code_muni_datasus") |>
    dplyr::select(-code_muni_datasus) |>
    sf::st_as_sf()

  climasus4r:::new_climasus_df(
    health_sf,
    list(system = cfg$health$system, stage = "spatial", type = "munic")
  )
}

#' Junta clima ao agregado de saúde e escreve o mart final (schema DATA_MODEL.md).
make_health_climate_mart <- function(health_daily, silver_inmet, cfg) {
  health_climasus <- build_health_sf(health_daily, cfg)

  joined <- climasus4r::sus_climate_aggregate(
    health_data       = health_climasus,
    climate_data      = silver_inmet,
    climate_var       = cfg$climate$climate_vars,
    time_unit         = "day",
    temporal_strategy = cfg$climate$temporal_strategy
  )

  mart <- joined |>
    sf::st_drop_geometry() |>
    dplyr::rename(
      tmean  = tair_dry_bulb_c,
      tmax   = tair_max_c,
      tmin   = tair_min_c,
      precip = rainfall_mm,
      rh     = rh_mean_porc
    ) |>
    # sus_climate_aggregate() promove deaths_*/geometria a double ao lidar com
    # NA nos joins internos — recasta para respeitar docs/DATA_MODEL.md.
    dplyr::mutate(dplyr::across(c(deaths_total, deaths_resp, deaths_circ), as.integer)) |>
    dplyr::arrange(code_muni, date) |>
    dplyr::select(code_muni, name_muni, date, deaths_total, deaths_resp, deaths_circ,
                  tmean, tmax, tmin, precip, rh)

  mart <- climasus4r:::new_climasus_df(
    mart,
    list(system = cfg$health$system, stage = "climate", type = "exact")
  )
  mart <- climasus4r::sus_meta(
    mart,
    user        = list(synthetic = FALSE, generator = "pipelines/_targets.R", uf = cfg$uf),
    add_history = "Real health-climate mart built via targets pipeline (Fase 1)"
  )

  out_dir <- file.path(cfg$paths$public, "gold", "health_climate_daily",
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(mart, out_path, chunk_size = cfg$gold$chunk_size)
  assert_climasus_meta(out_path)

  mart
}

#' Ondas de calor por estação (grão evento) — dataset Gold novo, não consumido
#' pelo frontend do scaffold (Fase 0); adicionado para a Fase 1.
make_heatwave_events <- function(bronze_inmet, cfg) {
  hw <- climasus4r::sus_climate_compute_heatwaves(
    bronze_inmet,
    method         = cfg$heatwaves$methods,
    baseline_start = cfg$heatwaves$baseline_start,
    baseline_end   = cfg$heatwaves$baseline_end,
    percentile     = cfg$heatwaves$percentile
  )

  events <- climasus4r:::new_climasus_df(
    hw$events,
    list(system = cfg$health$system, stage = "climate", type = "heatwaves")
  )
  events <- climasus4r::sus_meta(
    events,
    user = list(synthetic = FALSE, generator = "pipelines/_targets.R", uf = cfg$uf)
  )

  out_dir <- file.path(cfg$paths$public, "gold", "heatwave_events",
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(events, out_path, chunk_size = cfg$gold$chunk_size)
  assert_climasus_meta(out_path)

  events
}

#' Dimensão de estações INMET (grão estação) — de station_meta.parquet, já
#' embutido no climasus4r; zero rede. Alimenta a camada deck.gl de estações
#' no atlas (Fase 2).
make_dim_station <- function(cfg) {
  station_meta_path <- system.file("data_4r", "station_meta.parquet", package = "climasus4r")
  stations <- arrow::read_parquet(station_meta_path) |>
    dplyr::filter(federal_unit == cfg$uf) |>
    dplyr::transmute(
      station_code, station_name,
      latitude = as.double(latitude), longitude = as.double(longitude)
    )

  stations_climasus <- climasus4r:::new_climasus_df(
    stations,
    list(system = NULL, stage = "climate", type = "inmet")
  )

  out_dir <- file.path(cfg$paths$public, "gold", "dim_station",
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(stations_climasus, out_path)
  assert_climasus_meta(out_path)

  stations_climasus
}
