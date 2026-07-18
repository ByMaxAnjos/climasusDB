#!/usr/bin/env Rscript
# Exporta as malhas geográficas nacionais (municípios, estados, regiões) via
# geobr, simplificadas para uso no atlas (MapLibre) — substitui o GeoJSON
# RO-only de 99_export_geo.R pela escala nacional, mantendo o mesmo modelo de
# serving (arquivo estático via HTTP, sem servidor de tiles). Alternativa mais
# leve (PMTiles + tippecanoe) fica em generate_pmtiles.R para quando o
# binário estiver disponível — hoje seguimos GeoJSON puro (sem nova
# dependência de sistema).
#
# Simplificação é feita numa projeção métrica (SIRGAS 2000 / Brazil Polyconic,
# EPSG:5880) e só depois reprojetada para 4326 (GeoJSON exige WGS84) — ao
# simplificar direto em graus (como o script antigo fazia) o tolerance numérico
# é interpretado em graus, o que é efetivamente um no-op nessa escala.
#
# Requer rede (baixa a malha do IBGE via geobr). Roda uma única vez; a saída é
# commitada em apps/web/public/geo/{municipios,estados,regioes}_br.geojson.
#
# Uso: Rscript pipelines/R/99_export_geo_br.R

suppressPackageStartupMessages({
  library(geobr)
  library(sf)
  library(dplyr)
})

METRIC_CRS <- 5880 # SIRGAS 2000 / Brazil Polyconic (metros)
OUT_DIR <- file.path("apps", "web", "public", "geo")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Simplifica em CRS métrico; se algum polígono colapsar (geometria vazia),
# mantém a geometria original para essa feature em vez de perder o município.
simplify_safe <- function(sf_obj, tolerance_m) {
  original_geom <- sf::st_geometry(sf_obj)
  simplified <- sf_obj |>
    sf::st_transform(METRIC_CRS) |>
    sf::st_simplify(dTolerance = tolerance_m) |>
    sf::st_transform(4326)
  empty <- sf::st_is_empty(simplified)
  if (any(empty)) {
    sf::st_geometry(simplified)[empty] <- sf::st_transform(original_geom[empty], 4326)
    cli::cli_alert_warning("{sum(empty)} geometria(s) colapsaram na simplificação e foram mantidas no detalhe original.")
  }
  simplified
}

write_geojson <- function(sf_obj, out_path) {
  if (file.exists(out_path)) file.remove(out_path)
  sf::st_write(sf_obj, out_path, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
  cli::cli_alert_success("{out_path} salvo ({nrow(sf_obj)} feições, {round(file.size(out_path) / 1024)} KB).")
}

# ---- 1. Municípios (todos, 5.570) ------------------------------------------

cli::cli_alert_info("Baixando malha municipal do Brasil via geobr (rede necessária, pode levar alguns minutos)...")
municipios <- geobr::read_municipality(code_muni = "all", year = 2022) |>
  simplify_safe(tolerance_m = 1000) |>
  transmute(
    code_muni = as.integer(code_muni),
    name_muni = name_muni,
    code_state = as.integer(code_state),
    abbrev_state = abbrev_state,
    name_state = name_state,
    code_region = as.integer(code_region),
    name_region = name_region
  )
write_geojson(municipios, file.path(OUT_DIR, "municipios_br.geojson"))

# ---- 2. Estados (27) --------------------------------------------------------

cli::cli_alert_info("Baixando malha estadual do Brasil via geobr...")
estados <- geobr::read_state(year = 2020) |>
  simplify_safe(tolerance_m = 500) |>
  transmute(
    code_state = as.integer(code_state),
    abbrev_state = abbrev_state,
    name_state = name_state,
    code_region = as.integer(code_region),
    name_region = name_region
  )
write_geojson(estados, file.path(OUT_DIR, "estados_br.geojson"))

# ---- 3. Regiões (5) ---------------------------------------------------------

cli::cli_alert_info("Baixando malha das grandes regiões via geobr...")
regioes <- geobr::read_region(year = 2020) |>
  simplify_safe(tolerance_m = 500) |>
  transmute(code_region = as.integer(code_region), name_region = name_region)
write_geojson(regioes, file.path(OUT_DIR, "regioes_br.geojson"))

cli::cli_alert_success("Malhas nacionais exportadas em {OUT_DIR}.")
