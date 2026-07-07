#!/usr/bin/env Rscript
# Confere que um Parquet Gold `health_climate_daily` respeita o contrato de
# schema em docs/DATA_MODEL.md — usado pelo scaffold sintético (Fase 0) e pelo
# real (Fase 1) para garantir que ambos sejam intercambiáveis pelo frontend.
#
# Uso: Rscript pipelines/R/check_schema.R <path-para-data.parquet>

suppressPackageStartupMessages(library(arrow))

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[[1]] else
  "data/public/gold/health_climate_daily/v0.1.0/uf=RO/data.parquet"

expected <- c(
  code_muni = "int32", name_muni = "string", date = "date32[day]",
  deaths_total = "int32", deaths_resp = "int32", deaths_circ = "int32",
  tmean = "double", tmax = "double", tmin = "double",
  precip = "double", rh = "double"
)

ds <- arrow::open_dataset(path)
actual <- setNames(
  vapply(ds$schema$fields, function(f) f$type$ToString(), character(1)),
  vapply(ds$schema$fields, function(f) f$name, character(1))
)

missing <- setdiff(names(expected), names(actual))
if (length(missing) > 0) {
  stop(sprintf("Colunas obrigatórias ausentes em %s: %s", path, paste(missing, collapse = ", ")))
}

mismatched <- names(expected)[expected != actual[names(expected)]]
if (length(mismatched) > 0) {
  stop(sprintf(
    "Tipo divergente do contrato (docs/DATA_MODEL.md) em %s: %s",
    path,
    paste(sprintf("%s (esperado %s, veio %s)", mismatched, expected[mismatched], actual[mismatched]), collapse = "; ")
  ))
}

meta <- ds$schema$metadata[["climasus_meta"]]
if (is.null(meta)) stop(sprintf("Parquet sem climasus_meta embutido: %s", path))

cat(sprintf("OK: %s respeita o contrato de schema (%d colunas, climasus_meta presente).\n", path, length(expected)))
