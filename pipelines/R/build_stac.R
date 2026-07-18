#!/usr/bin/env Rscript
# Fase 3 — catálogo STAC estático (JSON puro, sem servidor) para as coleções
# GRIDDED (ERA5, CHIRPS, ...) publicadas na Fase 2. Datasets tabulares
# continuam descritos por datapackage.json (pipelines/R/catalog.R) — STAC é
# desenhado para assets espaço-temporais raster, não para tabelas.
#
# Convenção: um dataset é "gridded" se seu nome está em `gridded_datasets`
# (abaixo) — evita inferir isso do schema, mais simples e explícito.
#
# Uso: Rscript pipelines/R/build_stac.R

suppressPackageStartupMessages({
  library(arrow)
  library(jsonlite)
  library(cli)
})

gridded_datasets <- c("env_era5_daily", "env_chirps_daily", "env_prodes_daily", "env_pollution_cams_daily") # nomes usados por make_gridded_gold(), ver pipelines/R/run_gridded.R

find_gridded_files <- function(public_dir, dataset) {
  Sys.glob(file.path(public_dir, "gold", dataset, "v*", "uf=*", "data.parquet"))
}

build_stac_item <- function(path, rel_path, dataset, version, uf) {
  ds <- arrow::open_dataset(path)
  meta_json <- ds$schema$metadata[["climasus_meta"]]
  meta <- if (!is.null(meta_json)) jsonlite::fromJSON(meta_json, simplifyVector = TRUE) else list()

  list(
    stac_version = "1.0.0",
    type = "Feature",
    id = sprintf("%s-v%s-uf-%s", dataset, version, uf),
    collection = dataset,
    properties = list(
      datetime = meta$created %||% format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
      uf = uf,
      version = version
    ),
    assets = list(
      # href relativo a data/public (mesma convenção do datapackage.json) —
      # um caminho local de filesystem seria inservível via HTTP/GCS.
      data = list(href = rel_path, type = "application/x-parquet", title = "Parquet")
    ),
    links = list()
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

build_stac_collection <- function(dataset, items) {
  list(
    stac_version = "1.0.0",
    type = "Collection",
    id = dataset,
    description = sprintf("Coleção gridded '%s' do climasusDB (Fase 2/3).", dataset),
    license = "CC-BY-4.0",
    extent = list(
      spatial = list(bbox = list(c(-73.99, -33.75, -28.84, 5.27))), # bbox Brasil (aprox.)
      temporal = list(interval = list(c(NA, NA)))
    ),
    links = lapply(seq_along(items), function(i) {
      list(rel = "item", href = sprintf("./items/%s.json", items[[i]]$id))
    })
  )
}

build_stac <- function(public_dir) {
  stac_dir <- file.path(public_dir, "stac")
  collections <- list()

  for (dataset in gridded_datasets) {
    files <- find_gridded_files(public_dir, dataset)
    if (length(files) == 0) {
      cli::cli_alert_info("Nenhum arquivo para coleção gridded '{dataset}' ainda — pulando.")
      next
    }

    items <- lapply(files, function(path) {
      parts <- strsplit(path, "/", fixed = TRUE)[[1]]
      n <- length(parts)
      version <- sub("^v", "", parts[n - 2])
      uf <- sub("^uf=", "", parts[n - 1])
      rel_path <- sub(paste0("^", public_dir, "/?"), "", path)
      build_stac_item(path, rel_path, dataset, version, uf)
    })

    coll_dir <- file.path(stac_dir, "collections", dataset, "items")
    dir.create(coll_dir, recursive = TRUE, showWarnings = FALSE)
    for (item in items) {
      jsonlite::write_json(item, file.path(coll_dir, paste0(item$id, ".json")), auto_unbox = TRUE, pretty = TRUE)
    }

    collection <- build_stac_collection(dataset, items)
    jsonlite::write_json(
      collection,
      file.path(stac_dir, "collections", dataset, "collection.json"),
      auto_unbox = TRUE, pretty = TRUE
    )
    collections[[dataset]] <- collection
  }

  catalog <- list(
    stac_version = "1.0.0",
    type = "Catalog",
    id = "climasusdb",
    description = "Catálogo STAC das coleções gridded do climasusDB.",
    links = lapply(names(collections), function(id) {
      list(rel = "child", href = sprintf("./collections/%s/collection.json", id))
    })
  )
  dir.create(stac_dir, recursive = TRUE, showWarnings = FALSE)
  catalog_path <- file.path(stac_dir, "catalog.json")
  jsonlite::write_json(catalog, catalog_path, auto_unbox = TRUE, pretty = TRUE)

  cli::cli_alert_success("STAC gerado em {catalog_path} ({length(collections)} coleção/coleções).")
  catalog_path
}

if (sys.nframe() == 0) build_stac("data/public")
