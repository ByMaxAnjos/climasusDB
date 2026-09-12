# Funções de leitura/checagem usadas pelo painel interno (dashboard.Rmd) e,
# no caso do contrato de schema, pelo `make check` (check_schema.R). Nenhuma
# função aqui baixa dado ou modifica data/public — só lê o que já foi
# publicado por make national/make data-synth.

#' Caminhos completos das partições "mais recentes" de um dataset Gold,
#' segundo data/public/catalog.json (já resolvido por pipelines/R/catalog.R —
#' evita reimplementar a lógica de "qual versão é a latest" aqui).
latest_paths_for <- function(dataset, catalog_path = "data/public/catalog.json") {
  if (!file.exists(catalog_path)) return(character(0))
  catalog <- jsonlite::fromJSON(catalog_path, simplifyVector = FALSE)
  entry <- Filter(function(d) identical(d$name, dataset), catalog$datasets)
  if (length(entry) == 0) return(character(0))
  vapply(entry[[1]]$partitions, function(p) file.path("data/public", p$path), character(1))
}

#' Confere o contrato de schema (docs/DATA_MODEL.md) de cada partição
#' encontrada, sem parar na primeira falha — usada por check_schema.R (CLI)
#' e pelo painel (relatório completo por UF/versão).
check_schema_report <- function(paths = NULL) {
  if (is.null(paths)) {
    paths <- Sys.glob("data/public/gold/health_climate_daily/v*/uf=*/data.parquet")
  }
  expected <- c(
    code_muni = "int32", name_muni = "string", date = "date32[day]",
    deaths_total = "int32", deaths_resp = "int32", deaths_circ = "int32",
    tmean = "double", tmax = "double", tmin = "double",
    precip = "double", rh = "double"
  )
  rows <- lapply(paths, function(path) {
    problem <- tryCatch(
      {
        ds <- arrow::open_dataset(path)
        actual <- setNames(
          vapply(ds$schema$fields, function(f) f$type$ToString(), character(1)),
          vapply(ds$schema$fields, function(f) f$name, character(1))
        )
        missing <- setdiff(names(expected), names(actual))
        if (length(missing) > 0) {
          return(sprintf("colunas ausentes: %s", paste(missing, collapse = ", ")))
        }
        mismatched <- names(expected)[expected != actual[names(expected)]]
        if (length(mismatched) > 0) {
          return(sprintf("tipo divergente: %s", paste(mismatched, collapse = ", ")))
        }
        if (is.null(ds$schema$metadata[["climasus_meta"]])) {
          return("climasus_meta ausente")
        }
        NA_character_
      },
      error = function(e) conditionMessage(e)
    )
    data.frame(
      path = path,
      uf = sub(".*uf=([A-Za-z0-9]+).*", "\\1", path),
      version = sub(".*/(v[0-9]+\\.[0-9]+\\.[0-9]+)/.*", "\\1", path),
      ok = is.na(problem),
      problem = problem,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Cobertura de municípios de health_climate_daily (latest) vs. o total do
#' IBGE embutido no climasus4r (municipio_meta.parquet).
coverage_report <- function(paths = latest_paths_for("health_climate_daily")) {
  present <- unique(unlist(lapply(paths, function(p) {
    arrow::open_dataset(p) |> dplyr::distinct(code_muni) |> dplyr::collect() |> dplyr::pull(code_muni)
  })))
  muni_meta_path <- system.file("data_4r", "municipio_meta.parquet", package = "climasus4r")
  all_muni <- arrow::read_parquet(muni_meta_path)
  missing <- all_muni |> dplyr::filter(!as.integer(municipio) %in% present)
  list(n_present = length(present), n_total = nrow(all_muni), missing = missing)
}

#' % de linhas com tmean ausente (NA) por UF, no latest de health_climate_daily
#' — reflete a cobertura pós-preenchimento (fill_gap), não o dado bruto.
imputation_report <- function(paths = latest_paths_for("health_climate_daily")) {
  rows <- lapply(paths, function(path) {
    ds <- arrow::open_dataset(path)
    total <- ds |> dplyr::count() |> dplyr::collect() |> dplyr::pull(n)
    missing <- ds |> dplyr::filter(is.na(tmean)) |> dplyr::count() |> dplyr::collect() |> dplyr::pull(n)
    data.frame(
      uf = sub(".*uf=([A-Za-z0-9]+).*", "\\1", path),
      total_rows = total, tmean_na = missing,
      pct_na = round(100 * missing / total, 1),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Células com contagem de óbitos entre 1 e threshold-1 (risco de
#' reidentificação), por UF — mesmo limiar de check_small_cells.R, agora
#' agregado nacionalmente em vez de uma partição por vez.
small_cells_report <- function(paths = latest_paths_for("health_climate_daily"), threshold = 5L) {
  rows <- lapply(paths, function(path) {
    ds <- arrow::open_dataset(path)
    small <- ds |>
      dplyr::filter(deaths_total > 0 & deaths_total < threshold) |>
      dplyr::count(code_muni) |>
      dplyr::collect()
    data.frame(
      uf = sub(".*uf=([A-Za-z0-9]+).*", "\\1", path),
      n_municipios_small = nrow(small),
      n_small_cells = sum(small$n),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Inventário do catálogo publicado (data/public/catalog.json) — 1 linha por
#' dataset: versão mais recente, sintético ou real, nº de partições e linhas.
catalog_inventory <- function(catalog_path = "data/public/catalog.json") {
  if (!file.exists(catalog_path)) return(data.frame())
  catalog <- jsonlite::fromJSON(catalog_path, simplifyVector = FALSE)
  rows <- lapply(catalog$datasets, function(d) {
    data.frame(
      dataset = d$name, latest = d$latest, synthetic = isTRUE(d$synthetic),
      n_partitions = length(d$partitions),
      total_rows = sum(vapply(d$partitions, function(p) as.numeric(p$rows %||% 0), numeric(1))),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Registro manual de parceiros/aplicações de terceiros que usam dados do
#' climasusDB — mantido à mão em pipelines/config/third_party_apps.yaml
#' (não há telemetria de uso real; ver docs/PLANO.md).
third_party_registry <- function(path = "pipelines/config/third_party_apps.yaml") {
  cols <- c("name", "contact", "datasets", "link", "status", "notes")
  empty <- setNames(data.frame(matrix(nrow = 0, ncol = length(cols))), cols)
  if (!file.exists(path)) return(empty)
  cfg <- yaml::read_yaml(path)
  apps <- cfg$apps %||% list()
  if (length(apps) == 0) return(empty)
  rows <- lapply(apps, function(a) {
    data.frame(
      name = a$name %||% NA, contact = a$contact %||% NA,
      datasets = paste(unlist(a$datasets), collapse = ", "),
      link = a$link %||% NA, status = a$status %||% NA,
      notes = a$notes %||% NA,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
