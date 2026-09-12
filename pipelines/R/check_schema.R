#!/usr/bin/env Rscript
# Confere que um Parquet Gold `health_climate_daily` respeita o contrato de
# schema em docs/DATA_MODEL.md — usado pelo scaffold sintético (Fase 0) e pelo
# real (Fase 1) para garantir que ambos sejam intercambiáveis pelo frontend.
#
# Uso: Rscript pipelines/R/check_schema.R [path-para-data.parquet]
#   Sem argumento: valida TODAS as partições de health_climate_daily
#   encontradas em data/public/gold (todas as versões/UFs).

suppressPackageStartupMessages(library(arrow))
source("pipelines/R/dashboard_helpers.R")

args <- commandArgs(trailingOnly = TRUE)
paths <- if (length(args) >= 1) args[[1]] else
  Sys.glob("data/public/gold/health_climate_daily/v*/uf=*/data.parquet")
if (length(paths) == 0) stop("Nenhum Parquet de health_climate_daily encontrado em data/public/gold.")

report <- check_schema_report(paths)
failed <- report[!report$ok, ]
if (nrow(failed) > 0) {
  stop(sprintf(
    "Contrato de schema (docs/DATA_MODEL.md) falhou em %d de %d partição(ões):\n%s",
    nrow(failed), nrow(report),
    paste(sprintf("  %s: %s", failed$path, failed$problem), collapse = "\n")
  ))
}
cat(sprintf(
  "OK: %d partição(ões) respeitam o contrato de schema (11 colunas, climasus_meta presente).\n",
  nrow(report)
))
