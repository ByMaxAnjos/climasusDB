#!/usr/bin/env Rscript
# Exporta os polígonos municipais reais de Rondônia via geobr, simplificados
# para uso no atlas (MapLibre choropleth). Roda uma única vez; a saída é
# commitada em apps/web/public/geo/municipios_ro.geojson.
#
# Requer rede (baixa malha do IBGE via geobr). Se você não tem rede agora,
# um GeoJSON placeholder (quadrados centrados no centróide de cada município,
# a partir de municipio_meta.parquet) já foi gerado para permitir testar o
# atlas hoje — rode este script depois e ele substitui o placeholder pela
# geometria real, sem exigir nenhuma mudança no frontend (mesmo nome de
# arquivo, mesmas propriedades `code_muni`/`name_muni`).
#
# Uso: Rscript pipelines/R/99_export_geo.R

suppressPackageStartupMessages({
  library(geobr)
  library(sf)
  library(dplyr)
})

ro <- geobr::read_municipality(code_muni = "RO", year = 2022) |>
  sf::st_simplify(dTolerance = 200) |>
  sf::st_transform(4326) |>
  transmute(
    code_muni = as.integer(code_muni),
    name_muni = name_muni
  )

out_path <- file.path("apps", "web", "public", "geo", "municipios_ro.geojson")
if (file.exists(out_path)) file.remove(out_path)
sf::st_write(ro, out_path, driver = "GeoJSON", delete_dsn = TRUE)

cli::cli_alert_success("GeoJSON real de RO salvo em {out_path} ({nrow(ro)} municípios).")
