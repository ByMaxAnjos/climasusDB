# Gera datapackage.json por dataset/versão + catalog.json raiz, lendo a
# proveniência embutida (climasus_meta) direto do schema Arrow de cada Parquet
# Gold. Falha (não avisa) se algum Gold não tiver a chave — é o jeito da
# plataforma garantir que ninguém publicou um dataset "mudo".

find_gold_files <- function(public_dir) {
  Sys.glob(file.path(public_dir, "gold", "*", "v*", "uf=*", "data.parquet"))
}

read_climasus_meta <- function(path) {
  ds <- arrow::open_dataset(path)
  meta_json <- ds$schema$metadata[["climasus_meta"]]
  if (is.null(meta_json)) {
    cli::cli_abort("Parquet Gold sem climasus_meta (proveniência ausente): {.path {path}}")
  }
  jsonlite::fromJSON(meta_json, simplifyVector = TRUE)
}

dataset_info_from_path <- function(path) {
  # .../gold/{dataset}/v{version}/uf={uf}/data.parquet
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  n <- length(parts)
  list(
    dataset = parts[n - 3],
    version = sub("^v", "", parts[n - 2]),
    uf      = sub("^uf=", "", parts[n - 1])
  )
}

build_datapackage <- function(path, rel_path, meta, info) {
  ds <- arrow::open_dataset(path)
  list(
    name        = info$dataset,
    version     = info$version,
    description = sprintf("Gold dataset '%s', uf=%s. Ver docs/DATA_MODEL.md.", info$dataset, info$uf),
    licenses    = list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/")),
    resources   = list(list(
      name   = info$dataset,
      path   = rel_path, # relativo a data/public — mesmo caminho servido por HTTP/GCS
      format = "parquet",
      schema = list(fields = purrr::map(ds$schema$fields, function(field) {
        list(name = field$name, type = field$type$ToString())
      }))
    )),
    climasus_meta = meta,
    rows        = tryCatch(nrow(ds), error = function(e) NA_integer_)
  )
}

#' Constrói catalog.json raiz + 1 datapackage.json por dataset Gold encontrado.
#' @param public_dir caminho para data/public
build_catalog <- function(public_dir) {
  files <- find_gold_files(public_dir)
  if (length(files) == 0) {
    cli::cli_abort("Nenhum Parquet Gold encontrado em {.path {public_dir}/gold}")
  }

  entries <- list()
  for (path in files) {
    info <- dataset_info_from_path(path)
    meta <- read_climasus_meta(path) # aborta aqui se a chave estiver ausente
    rel_path <- sub(paste0("^", public_dir, "/?"), "", path)
    dp <- build_datapackage(path, rel_path, meta, info)

    dp_path <- file.path(dirname(path), "datapackage.json")
    jsonlite::write_json(dp, dp_path, auto_unbox = TRUE, pretty = TRUE)

    key <- info$dataset
    if (is.null(entries[[key]])) entries[[key]] <- list(versions = character(0))
    entries[[key]]$versions <- c(entries[[key]]$versions, info$version)
    entries[[key]]$path   <- rel_path
    entries[[key]]$rows   <- dp$rows
    entries[[key]]$synthetic <- isTRUE(meta$user$synthetic)
  }

  datasets <- lapply(names(entries), function(key) {
    e <- entries[[key]]
    latest <- sort(e$versions, decreasing = TRUE)[1]
    list(
      name      = key,
      latest    = paste0("v", latest),
      versions  = paste0("v", sort(e$versions)),
      synthetic = e$synthetic,
      path      = e$path,
      rows      = e$rows
    )
  })

  catalog <- list(datasets = datasets)
  catalog_path <- file.path(public_dir, "catalog.json")
  jsonlite::write_json(catalog, catalog_path, auto_unbox = TRUE, pretty = TRUE)

  cli::cli_alert_success("Catálogo gerado: {catalog_path} ({length(datasets)} dataset(s))")
  catalog_path
}
