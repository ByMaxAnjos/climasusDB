#!/usr/bin/env Rscript
# Pipeline REAL (Fase 1) — SIM-DO + INMET para Rondônia.
#
# NÃO EXECUTADO como parte do scaffold da Fase 0: depende de download do
# DATASUS (microdatasus) e do INMET, que são lentos/instáveis. Escrito agora
# para documentar a sequência exata de funções do climasus4r e a meta de
# schema (mesma saída de docs/DATA_MODEL.md), para que 00_synth_data.R possa
# ser substituído sem tocar no frontend.
#
# Uso (quando tiver rede e tempo disponíveis):
#   Rscript pipelines/R/01_ro_gold.R

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

YEARS <- 2018:2023

# ---- 1. Bronze — download bruto (cacheado, retomável) ----------------------

sim_raw <- sus_data_import(
  uf     = "RO",
  year   = YEARS,
  system = "SIM-DO",
  cache_dir = "data/bronze/datasus"
)

inmet_raw <- sus_climate_inmet(
  years = YEARS,
  uf    = "RO",
  cache_dir = "data/bronze/inmet"
)

# ---- 2. Silver — padronização + filtro por grupos CID climate-sensitive ---

sim_silver <- sim_raw |>
  sus_data_clean_encoding() |>
  sus_data_standardize() |>
  sus_data_filter_cid(disease_group = "climate_sensitive_all")

# ---- 3. Gold — agregação município x dia + integração com clima -----------

health_daily <- sim_silver |>
  sus_data_aggregate(
    time_unit      = "day",
    fun            = "count",
    group_by       = "code_muni",
    complete_dates = TRUE
  )

gold <- sus_climate_aggregate(
  health_data        = health_daily,
  climate_data       = inmet_raw,
  climate_var        = c("tair_dry_bulb_c", "tair_max_c", "tair_min_c", "rainfall_mm", "rh_mean_porc"),
  time_unit          = "day",
  temporal_strategy  = "exact"
) |>
  rename(
    tmean  = tair_dry_bulb_c,
    tmax   = tair_max_c,
    tmin   = tair_min_c,
    precip = rainfall_mm,
    rh     = rh_mean_porc
  ) |>
  arrange(code_muni, date)

# ---- 4. Persistir com proveniência (mesmo caminho lógico do sintético, v1.0.0) ----

gold <- sus_meta(gold, user = list(synthetic = FALSE, generator = "01_ro_gold.R", uf = "RO"))

out_dir <- file.path("data", "public", "gold", "health_climate_daily", "v1.0.0", "uf=RO")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write_parquet_climasus(gold, file.path(out_dir, "data.parquet"), chunk_size = 1e5)

# ---- 5. Relatório de qualidade (comparação com painéis oficiais é manual) --

sus_data_quality_report(gold)

cli::cli_alert_success("Gold real (v1.0.0) gerado. Atualize catalog.json apontando 'latest' para v1.0.0.")
