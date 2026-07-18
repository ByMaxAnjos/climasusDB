#!/usr/bin/env Rscript
# Fase 3 (trilha A) — liga as fontes gridded já suportadas pelo climasus4r
# (ERA5, CHIRPS, PRODES, poluição CAMS) ao mesmo layout Gold/Parquet usado
# por health_climate_daily. Cada fonte vira um dataset Gold próprio
# (env_<fonte>_daily), particionado por UF, agregado por município via
# exactextractr dentro de cada sus_grid_*(). Independente de run_national.R
# (não baixa saúde/INMET).
#
# Uso: Rscript pipelines/R/run_gridded.R [uf1,uf2,...]   (default: cfg$uf_list)

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

source("pipelines/R/silver.R")  # assert_climasus_meta()
source("pipelines/R/gridded.R")
source("pipelines/R/catalog.R")

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args <- commandArgs(trailingOnly = TRUE)
ufs <- if (length(args) >= 1) strsplit(args[[1]], ",")[[1]] else cfg_base$uf_list

# sus_grid_{era5,chirps,prodes}() fazem zonal-stat/interseção poligonal
# (exactextractr / sf::st_intersects) — precisam de POLÍGONO de município,
# não do centróide-ponto de muni_points_ro() (gold.R), que é só o que
# health_climate_daily precisa para casar com estação INMET por distância.
# Reaproveita o geojson nacional já gerado por `make geo-br` (geobr real).
municipios_geojson <- "apps/web/public/geo/municipios_br.geojson"
if (!file.exists(municipios_geojson)) {
  cli::cli_abort("{municipios_geojson} não encontrado — rode `make geo-br` antes de `make gridded`.")
}
# Sem isso, sus_grid_prodes() aborta a interseção com "Loop 0 is not valid:
# Edge X crosses edge Y" em municípios cujo anel o S2 (geometria esférica,
# default do sf) considera inválido — mesmo sendo válido no modo planar
# clássico (pegadinha conhecida do geobr/S2 em escala nacional).
sf::sf_use_s2(FALSE)
muni_polygons_br <- sf::st_read(municipios_geojson, quiet = TRUE)

GETTERS <- list(
  era5           = get_gridded_era5,
  chirps         = get_gridded_chirps,
  prodes         = get_gridded_prodes,
  pollution_cams = get_gridded_pollution_cams
)

sources <- cfg_base$climate$gridded_sources
unknown <- setdiff(sources, names(GETTERS))
if (length(unknown) > 0) {
  cli::cli_alert_warning("Fonte(s) gridded desconhecida(s) em climate.gridded_sources: {unknown} — ignorando.")
  sources <- setdiff(sources, unknown)
}

for (uf in ufs) {
  cli::cli_h1("Gridded — UF: {uf}")
  cfg <- cfg_base
  cfg$uf <- uf
  muni_sf <- muni_polygons_br |>
    dplyr::filter(abbrev_state == uf) |>
    dplyr::select(code_muni, name_muni)

  for (src in sources) {
    result <- tryCatch({
      df <- GETTERS[[src]](cfg, muni_sf)
      make_gridded_gold(df, paste0("env_", src, "_daily"), cfg)
      "ok"
    }, error = function(e) {
      cli::cli_alert_danger("UF {uf} / {src} falhou: {conditionMessage(e)}")
      "erro"
    })
    cli::cli_alert_info("UF {uf} / {src}: {result}")
  }
}

build_catalog(cfg_base$paths$public)
cli::cli_alert_success("Pipeline gridded concluído.")
