#!/usr/bin/env Rscript
# Fase 2 — mesmo pipeline de run_national.R (bronze→silver→gold, uma UF por
# vez), mas lê o SIM-DO de um bronze já baixado localmente via
# inst/scripts/create_national_database.R (climasus4r) em vez de baixar via
# rede — feito para rodar na máquina onde esse bronze já existe.
#
# O que NÃO vem do cache local: INMET (clima) não é coberto por
# create_national_database.R (é um dataset DATASUS-only) — ainda baixa via
# rede aqui, uma UF por vez, igual ao pipeline original.
#
# Uso: Rscript pipelines/R/run_national_from_cache.R <cache_root> [uf1,uf2,...]
#   cache_root = diretório passado como --output-dir para
#                create_national_database.R (ex.: ~/datasus_br)
#
# Depois de rodar: sincronize só data/public/gold/ (bem menor que o bronze)
# de volta para o reppositório climasusDB nesta máquina — não precisa mover
# o bronze bruto.

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

source("pipelines/R/bronze.R")
source("pipelines/R/silver.R")
source("pipelines/R/gold.R")
source("pipelines/R/catalog.R")
source("pipelines/R/run_national_common.R")

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  cli::cli_abort("Uso: Rscript pipelines/R/run_national_from_cache.R <cache_root> [uf1,uf2,...]")
}
cache_root <- path.expand(args[[1]])
if (!dir.exists(cache_root)) {
  cli::cli_abort("cache_root não existe: {cache_root}")
}
ufs <- if (length(args) >= 2) strsplit(args[[2]], ",")[[1]] else cfg_base$uf_list

run_national_pipeline(cfg_base, ufs, function(cfg) get_bronze_sim_from_cache(cfg, cache_root))

build_catalog(cfg_base$paths$public)
cli::cli_alert_success("Pipeline nacional (a partir do cache local) concluído.")
