#!/usr/bin/env Rscript
# Uso (offline): Rscript --vanilla pipelines/R/run_climate_outcomes.R RO [output_dir] [config.yaml]
suppressPackageStartupMessages({ library(climasus4r); library(dplyr) })
if (!"from_arrow_climasus" %in% getNamespaceExports("climasus4r"))
  pkgload::load_all("../climasus4r", quiet = TRUE)
source("pipelines/R/silver.R")
source("pipelines/R/run_national_common.R")
source("pipelines/R/climate_outcomes.R")
source("pipelines/R/catalog.R")
args <- commandArgs(trailingOnly = TRUE)
uf <- if (length(args)) args[[1]] else "RO"
if (length(uf) != 1L || !uf %in% c("RO", "AC", "AP", "AM", "RR", "TO", "PA", "AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE", "DF", "GO", "MT", "MS", "ES", "MG", "RJ", "SP", "PR", "RS", "SC")) stop("Informe uma única UF")
cfg <- yaml::read_yaml(if (length(args) >= 3L) args[[3]] else "pipelines/config/br_full.yaml")
cfg$uf <- uf
if (length(args) >= 2L) cfg$paths$public <- args[[2]]
cfg$climate_outcomes <- modifyList(list(year_min = 2012L, year_max = 2023L,
  exclude_years = c(2020L, 2021L), population_path = "data/reference/ibge_population_muni_year.parquet"), if (is.null(cfg$climate_outcomes)) list() else cfg$climate_outcomes)
out <- run_cached_gold_pipeline(cfg, uf, make_climate_outcomes)[[1]]
status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "pipelines/R/check_schema.R", shQuote(out)))
if (status != 0L) stop("Schema inválido")
status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "pipelines/R/check_small_cells.R", "5", shQuote(out)))
if (status != 0L) stop("Supressão inválida")
build_catalog(cfg$paths$public)
