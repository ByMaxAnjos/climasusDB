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
source("pipelines/R/run_national_common.R")

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args <- commandArgs(trailingOnly = TRUE)
ufs <- if (length(args) >= 1) strsplit(args[[1]], ",")[[1]] else cfg_base$uf_list

run_national_pipeline(cfg_base, ufs, get_bronze_sim)

build_catalog(cfg_base$paths$public)

# Força o contrato de docs/DATA_MODEL.md sobre tudo que acabou de ser escrito.
if (system2("Rscript", "pipelines/R/check_schema.R") != 0) {
  cli::cli_alert_danger("Contrato de schema violado — ver saída de check_schema.R acima.")
}

# run_national.R só baixa saúde/clima (SIM-DO + INMET); a malha de
# municípios (PMTiles) é gerada à parte por generate_pmtiles.R (`make
# tiles-br`, requer rede + tippecanoe) e é o que Map.tsx usa para renderizar
# o mapa nacional — dados de saúde/clima sem PMTiles = atlas sem mapa
# navegável. Checagem simples: arquivo existe e não está vazio.
pmtiles_path <- cfg_base$tiles$output
pmtiles_ok <- file.exists(pmtiles_path) && file.info(pmtiles_path)$size > 0
if (pmtiles_ok) {
  size_mb <- round(file.info(pmtiles_path)$size / 1e6, 1)
  cli::cli_alert_success("PMTiles nacional ativo: {pmtiles_path} ({size_mb} MB).")
} else {
  cli::cli_alert_warning(
    "PMTiles nacional ausente/vazio em {pmtiles_path} — o atlas não vai renderizar municípios até rodar: make tiles-br"
  )
}

cli::cli_alert_success("Pipeline nacional concluído.")
