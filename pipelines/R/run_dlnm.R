#!/usr/bin/env Rscript
# Fase 2b — indicador de risco relativo (DLNM), 1 modelo por UF.
#
# NÃO baixa nada de novo: lê silver_sim e silver_inmet (já preenchido por
# fill_bronze_inmet()) diretamente do que run_national.R já deixou em disco
# (data/silver/...). Só reprocessa o join espacial saúde x clima com
# temporal_strategy="distributed_lag" (o mart publicado usa "exact", sem
# colunas de lag — ver comentário em pipelines/R/dlnm.R) e ajusta o DLNM.
#
# Pré-requisito: rodar pipelines/R/run_national.R (ou run_national_from_cache.R)
# primeiro, para as UFs que você quer processar aqui — sem isso não há
# data/silver/{sim_do,inmet_hourly}/uf=XX para ler.
#
# Uso: Rscript pipelines/R/run_dlnm.R [uf1,uf2,...]   (default: todas)

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

source("pipelines/R/bronze.R")
source("pipelines/R/silver.R")
source("pipelines/R/gold.R")
source("pipelines/R/dlnm.R")
source("pipelines/R/catalog.R")

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args <- commandArgs(trailingOnly = TRUE)
ufs <- if (length(args) >= 1) strsplit(args[[1]], ",")[[1]] else cfg_base$uf_list

read_silver <- function(dataset, cfg) {
  path <- file.path(cfg$paths$silver, dataset, paste0("uf=", cfg$uf), "data.parquet")
  if (!file.exists(path)) {
    cli::cli_abort(
      "Silver ausente em {.path {path}} — rode run_national.R para uf={cfg$uf} primeiro."
    )
  }
  climasus4r:::from_arrow_climasus(path)
}

for (uf in ufs) {
  cli::cli_h1("UF: {uf} — DLNM")
  cfg <- cfg_base
  cfg$uf <- uf

  result <- tryCatch({
    silver_sim   <- read_silver("sim_do", cfg)
    silver_inmet <- read_silver("inmet_hourly", cfg)

    health_daily <- make_health_daily(silver_sim, cfg)
    dl_mart      <- make_distributed_lag_mart(health_daily, silver_inmet, cfg)
    fit          <- make_dlnm_relative_risk(dl_mart, cfg)

    cli::cli_alert_info(
      "UF {uf}: RR p75 vs mediana = {round(fit$models$rr, 3)} [{round(fit$models$lo, 3)}, {round(fit$models$hi, 3)}], lag pico = {fit$models$lag_peak}d, dispersão = {round(fit$diagnostics$disp_ratio, 2)}"
    )
    "ok"
  }, error = function(e) {
    cli::cli_alert_danger("UF {uf} falhou: {conditionMessage(e)}")
    "erro"
  })

  cli::cli_alert_info("UF {uf}: {result}")
}

build_catalog(cfg_base$paths$public)
cli::cli_alert_success("DLNM concluído.")
