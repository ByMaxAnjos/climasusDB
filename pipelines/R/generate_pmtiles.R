#!/usr/bin/env Rscript
# Fase 2 — gera tiles vetoriais (PMTiles) dos 5.570 municípios do Brasil.
# Substitui o GeoJSON estático (usado só para RO na Fase 0/1) na escala
# nacional, mantendo o mesmo modelo de serving (arquivo estático + HTTP
# range requests — sem servidor de tiles).
#
# Requer:
#   - rede (baixa a malha municipal via geobr)
#   - tippecanoe instalado (`brew install tippecanoe` no macOS)
#
# Uso: Rscript pipelines/R/generate_pmtiles.R

suppressPackageStartupMessages({
  library(geobr)
  library(sf)
  library(dplyr)
})

if (Sys.which("tippecanoe") == "") {
  stop(
    "tippecanoe não encontrado no PATH. Instale antes de rodar este script:\n",
    "  macOS: brew install tippecanoe\n",
    "  Linux: https://github.com/felt/tippecanoe#installation",
    call. = FALSE
  )
}

cfg <- yaml::read_yaml("pipelines/config/br_full.yaml")

cli::cli_alert_info("Baixando malha municipal do Brasil via geobr (rede necessária)...")
br <- geobr::read_municipality(code_muni = "all", year = 2022) |>
  sf::st_simplify(dTolerance = 100) |>
  sf::st_transform(4326) |>
  transmute(code_muni = as.integer(code_muni), name_muni = name_muni)

geojson_path <- tempfile(fileext = ".geojson")
sf::st_write(br, geojson_path, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)

out_path <- cfg$tiles$output
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

cli::cli_alert_info("Gerando PMTiles com tippecanoe...")
status <- system2(
  "tippecanoe",
  c(
    "-o", out_path, "--force",
    "--promote-id=code_muni", # id da feature = code_muni, usado no join com feature-state
    "-zg", "--drop-densest-as-needed",
    geojson_path
  )
)

if (status != 0) stop("tippecanoe falhou (status ", status, ")", call. = FALSE)

unlink(geojson_path)
cli::cli_alert_success("PMTiles nacional gerado em {out_path} ({nrow(br)} municípios).")
