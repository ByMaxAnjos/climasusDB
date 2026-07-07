library(targets)

tar_option_set(
  packages = c("climasus4r", "dplyr", "arrow", "cli", "jsonlite", "purrr"),
  format   = "rds"
)

source("pipelines/R/bronze.R")
source("pipelines/R/silver.R")
source("pipelines/R/gold.R")
source("pipelines/R/catalog.R")

list(
  tar_target(cfg_file, "pipelines/config/ro_mvp.yaml", format = "file"),
  tar_target(cfg, yaml::read_yaml(cfg_file)),

  # ---- Bronze (rede: DATASUS + INMET) ----------------------------------
  tar_target(bronze_sim, get_bronze_sim(cfg)),
  tar_target(bronze_inmet, get_bronze_inmet(cfg)),

  # ---- Silver ------------------------------------------------------------
  tar_target(silver_sim, make_silver_sim(bronze_sim, cfg)),
  tar_target(silver_inmet, make_silver_inmet(bronze_inmet, cfg)),

  # ---- Gold ---------------------------------------------------------------
  tar_target(health_daily, make_health_daily(silver_sim, cfg)),
  tar_target(gold_mart, make_health_climate_mart(health_daily, silver_inmet, cfg)),
  tar_target(gold_heatwaves, make_heatwave_events(bronze_inmet, cfg)),
  tar_target(gold_dim_station, make_dim_station(cfg)), # sem rede (station_meta.parquet embutido)

  # ---- Catálogo (sempre por último) --------------------------------------
  # Referenciar os targets Gold no corpo (mesmo sem usar o valor) faz o
  # {targets} detectar a dependência estaticamente e rodar isto por último.
  tar_target(catalog, {
    force(gold_mart)
    force(gold_heatwaves)
    force(gold_dim_station)
    build_catalog(cfg$paths$public)
  })
)
