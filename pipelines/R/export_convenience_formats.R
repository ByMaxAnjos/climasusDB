#!/usr/bin/env Rscript
# Exporta formatos de conveniência para o Catálogo de Dados.
#
# Regra:
# - Parquet continua sendo o formato canônico e sempre publicado.
# - CSV é publicado apenas quando o dataset é pequeno o bastante
#   para não virar um arquivo penoso de baixar/abrir.
# - Quando publicado, CSV é empacotado em ZIP.
#
# Critério objetivo atual:
# - apenas datasets pequenos/derivados entram em CSV
# - hoje isso inclui: dim_station, dlnm_exposure_response, dlnm_lag_response,
#   env_prodes_daily, health_climate_muni_summary e heatwave_events
# - dentro desse conjunto, cada partição ainda precisa ficar abaixo de 10 MiB
#
# Datasets que passam no corte recebem:
# - data.csv.zip
#
# Uso: Rscript pipelines/R/export_convenience_formats.R

suppressPackageStartupMessages({
  library(arrow)
  library(readr)
  library(zip)
  library(jsonlite)
})

MAX_PARTITION_MIB <- 10
ALLOWED_DATASETS <- c(
  "dim_station",
  "dlnm_exposure_response",
  "dlnm_lag_response",
  "env_prodes_daily",
  "health_climate_muni_summary",
  "heatwave_events"
)

public_dir <- file.path("data", "public")
paths <- Sys.glob(file.path(public_dir, "gold", "*", "v*", "uf=*", "data.parquet"))
catalog <- jsonlite::fromJSON(file.path(public_dir, "catalog.json"), simplifyVector = FALSE)

if (length(paths) == 0) {
  cli::cli_abort("Nenhum Parquet Gold encontrado em {.path {public_dir}/gold}")
}

export_partition <- function(path) {
  dataset_name <- basename(dirname(dirname(dirname(path))))
  if (!(dataset_name %in% ALLOWED_DATASETS)) {
    return(invisible(FALSE))
  }

  if (file.size(path) / 1024^2 > MAX_PARTITION_MIB) {
    return(invisible(FALSE))
  }

  parquet_size_mib <- round(file.size(path) / 1024^2, 1)
  dir <- dirname(path)
  base <- tools::file_path_sans_ext(basename(path))
  df <- arrow::read_parquet(path)

  csv_file <- file.path(dir, paste0(base, ".csv"))
  csv_zip <- file.path(dir, paste0(base, ".csv.zip"))
  csv_name <- basename(csv_file)
  csv_zip_name <- basename(csv_zip)

  oldwd <- getwd()
  on.exit(setwd(oldwd), add = TRUE)
  setwd(dir)
  readr::write_csv(df, csv_name)
  zip::zipr(csv_zip_name, files = csv_name)
  file.remove(csv_name)

  cli::cli_alert_success(
    "{path} -> CSV publicado (zipado) [{nrow(df)} linhas, {parquet_size_mib} MiB]"
  )
  invisible(TRUE)
}

invisible(lapply(paths, export_partition))

cli::cli_alert_success("Exportes de conveniência concluídos.")
