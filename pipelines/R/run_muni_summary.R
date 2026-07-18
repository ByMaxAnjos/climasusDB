#!/usr/bin/env Rscript
# Fase 2c — resumo de mortalidade por município, agregando health_climate_daily
# já publicado (2018-2023). Não baixa nada, não reprocessa saúde/clima — só
# lê o Gold mart existente por UF e soma por município.
#
# Pré-requisito: health_climate_daily já publicado para as UFs desejadas
# (rodar pipelines/R/run_national.R primeiro).
#
# Uso: Rscript pipelines/R/run_muni_summary.R [uf1,uf2,...]   (default: todas)

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

source("pipelines/R/silver.R")   # assert_climasus_meta()
source("pipelines/R/muni_summary.R")
source("pipelines/R/catalog.R")

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args <- commandArgs(trailingOnly = TRUE)
ufs <- if (length(args) >= 1) strsplit(args[[1]], ",")[[1]] else cfg_base$uf_list

for (uf in ufs) {
  cli::cli_h1("UF: {uf} — resumo por município")
  cfg <- cfg_base
  cfg$uf <- uf

  result <- tryCatch({
    summary_df <- make_muni_mortality_summary(cfg)
    cli::cli_alert_info(
      "UF {uf}: {nrow(summary_df)} municipios, {sum(summary_df$deaths_total)} obitos totais"
    )
    "ok"
  }, error = function(e) {
    cli::cli_alert_danger("UF {uf} falhou: {conditionMessage(e)}")
    "erro"
  })

  cli::cli_alert_info("UF {uf}: {result}")
}

build_catalog(cfg_base$paths$public)
cli::cli_alert_success("Resumo por municipio concluido.")
