#!/usr/bin/env Rscript
# Fase 2 — orquestra o MESMO pipeline da Fase 1 (bronze.R/silver.R/gold.R),
# uma UF por vez, para as 27 UFs do Brasil. Reaproveita 100% da lógica já
# validada no MVP de RO — só o `uf` de cada chamada muda, produzindo uma
# partição Hive (`uf=XX`) por vez sob o mesmo dataset/versão.
#
# ⚠️ Escopo grande (L no roadmap): 27 UFs x 6 anos de SIM-DO + INMET. Rodar
# com tempo disponível; cada UF é retomável independentemente (cache do
# climasus4r por parâmetros) se a execução for interrompida.
#
# Uso: Rscript pipelines/R/run_national.R [uf1,uf2,...]   (default: todas)

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

source("pipelines/R/bronze.R")
source("pipelines/R/silver.R")
source("pipelines/R/gold.R")
source("pipelines/R/catalog.R")

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args <- commandArgs(trailingOnly = TRUE)
ufs <- if (length(args) >= 1) strsplit(args[[1]], ",")[[1]] else cfg_base$uf_list

for (uf in ufs) {
  cli::cli_h1("UF: {uf}")
  cfg <- cfg_base
  cfg$uf <- uf # os wrappers de bronze/silver/gold já são parametrizados por cfg$uf

  result <- tryCatch({
    bronze_sim   <- get_bronze_sim(cfg)
    bronze_inmet <- get_bronze_inmet(cfg)
    silver_sim   <- make_silver_sim(bronze_sim, cfg)
    silver_inmet <- make_silver_inmet(bronze_inmet, cfg)
    health_daily <- make_health_daily(silver_sim, cfg)
    make_health_climate_mart(health_daily, silver_inmet, cfg)
    make_heatwave_events(bronze_inmet, cfg)
    "ok"
  }, error = function(e) {
    cli::cli_alert_danger("UF {uf} falhou: {conditionMessage(e)}")
    "erro"
  })

  cli::cli_alert_info("UF {uf}: {result}")
}

build_catalog(cfg_base$paths$public)
cli::cli_alert_success("Pipeline nacional concluído.")
