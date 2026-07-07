#!/usr/bin/env Rscript
# Fase 3 — cria/atualiza um depósito Zenodo (DOI versionado) para um dataset
# Gold, usando o datapackage.json gerado por catalog.R como fonte de
# metadados (title/creators/license/version — mapeamento 1:1 comentado
# abaixo). Requer conta Zenodo + token de API — não executável sem isso;
# o código abaixo está pronto para rodar quando a conta existir (Fase 3).
#
# Uso:
#   export ZENODO_TOKEN="..."          # ~/.Renviron ou variável de ambiente
#   Rscript pipelines/R/zenodo_deposit.R <dataset_dir> [--sandbox]
#
# <dataset_dir> ex.: data/public/gold/health_climate_daily/v1.0.0/uf=RO

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(cli)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Uso: Rscript pipelines/R/zenodo_deposit.R <dataset_dir> [--sandbox]", call. = FALSE)
}
dataset_dir <- args[[1]]
sandbox <- "--sandbox" %in% args

token <- Sys.getenv("ZENODO_TOKEN")
if (token == "") {
  stop(
    "ZENODO_TOKEN não definido. Crie uma conta em https://zenodo.org, gere um ",
    "token de API pessoal (Applications > Personal access tokens) e defina:\n",
    "  export ZENODO_TOKEN=\"...\"\n",
    "Para testar sem publicar de verdade, use https://sandbox.zenodo.org e --sandbox.",
    call. = FALSE
  )
}

base_url <- if (sandbox) "https://sandbox.zenodo.org/api" else "https://zenodo.org/api"

dp_path <- file.path(dataset_dir, "datapackage.json")
if (!file.exists(dp_path)) {
  stop("datapackage.json não encontrado em ", dataset_dir,
       " — rode pipelines/R/catalog.R antes.", call. = FALSE)
}
dp <- jsonlite::fromJSON(dp_path, simplifyVector = TRUE)

# ---- Mapeamento datapackage.json -> metadados Zenodo -----------------------
zenodo_metadata <- list(
  metadata = list(
    title       = sprintf("climasusDB — %s (v%s)", dp$name, dp$version),
    upload_type = "dataset",
    description = dp$description,
    creators    = list(list(name = "Anjos, Max", affiliation = "CCSRO / climaSUS")),
    version     = dp$version,
    license     = "cc-by-4.0",
    keywords    = list("climate", "health", "Brazil", "DATASUS", "INMET")
  )
)

cli::cli_h1("Depositando '{dp$name}' v{dp$version} no Zenodo ({if (sandbox) 'sandbox' else 'produção'})")

# 1. Cria o depósito (rascunho)
resp <- request(paste0(base_url, "/deposit/depositions")) |>
  req_auth_bearer_token(token) |>
  req_body_json(zenodo_metadata) |>
  req_perform()
deposition <- resp_body_json(resp)
deposition_id <- deposition$id
bucket_url <- deposition$links$bucket

cli::cli_alert_success("Depósito criado: id={deposition_id}")

# 2. Envia os arquivos (Parquet + datapackage.json) para o bucket do depósito
files <- list.files(dataset_dir, full.names = TRUE, pattern = "\\.(parquet|json)$")
for (f in files) {
  cli::cli_alert_info("Enviando {basename(f)}...")
  request(paste0(bucket_url, "/", basename(f))) |>
    req_auth_bearer_token(token) |>
    req_method("PUT") |>
    req_body_file(f) |>
    req_perform()
}

cli::cli_alert_success(
  "Arquivos enviados. Revise o rascunho em {base_url |> sub('/api', '', x = _)}/deposit/{deposition_id} e publique manualmente."
)
cli::cli_alert_info("Publicação automática (POST .../actions/publish) foi deixada de fora de propósito — publicar um DOI é irreversível.")
