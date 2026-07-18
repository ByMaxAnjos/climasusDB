# Fase 3 (trilha A) — fontes de clima/ambiente em grade, sem API key (ERA5,
# CHIRPS, PRODES, poluição CAMS), complementares ao INMET em áreas com baixa
# densidade de estações e para variáveis que o INMET não mede (desmatamento,
# poluentes). Cada wrapper devolve um climasus_df já agregado por município
# (via exactextractr, embutido em cada sus_grid_*()), persistido pela mesma
# regra (write_parquet_climasus) em datasets Gold próprios (env_<fonte>_daily)
# — não são misturados no mart health_climate_daily porque nem toda UF/ano
# tem cobertura das 4 fontes ao mesmo tempo; quem quiser um mart combinado
# usa climasus4r::sus_grid_join() por fora.

stamp_gridded_meta <- function(df, cfg, generator) {
  df |>
    dplyr::mutate(code_muni = as.integer(code_muni)) |>
    climasus4r::sus_meta(
      user = list(synthetic = FALSE, generator = generator, uf = cfg$uf)
    )
}

get_gridded_era5 <- function(cfg, muni_sf) {
  climasus4r::sus_grid_era5(
    years          = cfg$years,
    municipalities = muni_sf
  ) |> stamp_gridded_meta(cfg, "pipelines/R/run_gridded.R")
}

get_gridded_chirps <- function(cfg, muni_sf) {
  climasus4r::sus_grid_chirps(
    years          = cfg$years,
    municipalities = muni_sf
  ) |> stamp_gridded_meta(cfg, "pipelines/R/run_gridded.R")
}

get_gridded_prodes <- function(cfg, muni_sf) {
  climasus4r::sus_grid_prodes(
    years          = cfg$years,
    uf             = cfg$uf,
    municipalities = muni_sf
  ) |> stamp_gridded_meta(cfg, "pipelines/R/run_gridded.R")
}

# sus_grid_pollution_cams() não recebe `municipalities`/`uf` — devolve o
# Brasil inteiro; filtramos para a UF corrente para manter a mesma partição
# Hive (uf=XX) dos demais datasets Gold.
get_gridded_pollution_cams <- function(cfg, muni_sf) {
  climasus4r::sus_grid_pollution_cams(
    years = cfg$years
  ) |>
    dplyr::mutate(code_muni = as.integer(code_muni)) |>
    dplyr::filter(code_muni %in% muni_sf$code_muni) |>
    stamp_gridded_meta(cfg, "pipelines/R/run_gridded.R")
}

#' Escreve um dataset gridded como Gold complementar (não é o mart principal).
make_gridded_gold <- function(df, dataset_name, cfg) {
  out_dir <- file.path(cfg$paths$public, "gold", dataset_name,
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(df, out_path, chunk_size = cfg$gold$chunk_size)
  assert_climasus_meta(out_path)
  df
}
