#!/usr/bin/env Rscript
# Reprocessa o indicador de óbitos climate-sensitive (health_climate_daily +
# health_climate_muni_summary) para as UFs pedidas, 100% a partir do cache
# local de Silver já em disco (data/silver/sim_do, data/silver/inmet_hourly)
# — NENHUM download novo do DATASUS/INMET. Não toca bronze/, INMET, DLNM,
# ondas de calor nem os datasets gridded: escopo é só o mart de saúde-clima
# e o resumo por município derivado dele.
#
# Corrige o grão do mart (achado de revisão por pares, ver docs/DATA_MODEL.md
# e pipelines/R/gold.R::full_muni_day_grid()): antes, health_climate_daily só
# tinha linha para município-dia COM óbito (complete_dates=TRUE não bastava,
# porque resolve_geo_col_name() só roda depois da agregação — nenhum
# group_by chegava a sus_data_aggregate()/complete_time_series(), que então
# completava só o eixo de datas globalmente, nunca o produto cartesiano
# município x data). Agora toda combinação município(UF) x dia(cfg$years)
# aparece, com deaths_total/resp/circ = 0 quando não houve óbito.
#
# A correção NÃO muda a contagem bruta de óbitos (só adiciona linhas
# zero-preenchidas) — sum(deaths_total) por UF deve ser idêntico ao valor
# hoje publicado em v1.0.0, salvo diferença de freshness do silver em cache
# (o SIM-DO recebe registros tardios; confira a data de download do bronze
# se a soma divergir).
#
# Pré-requisito: data/silver/{sim_do,inmet_hourly}/uf=XX/data.parquet já
# existentes (produzidos por run_national.R numa execução anterior).
#
# Publica como uma NOVA versão (default "1.1.0") em vez de sobrescrever
# v1.0.0 silenciosamente — quem consome o catálogo escolhe a versão
# explicitamente, e o release anterior continua citável.
#
# Uso:
#   Rscript pipelines/R/run_health_daily_fix.R                  # todas as UFs, v1.1.0
#   Rscript pipelines/R/run_health_daily_fix.R SP,RO             # só SP e RO, v1.1.0
#   Rscript pipelines/R/run_health_daily_fix.R SP,RO 1.1.0-rc1   # versão custom

suppressPackageStartupMessages({
  library(climasus4r)
  library(dplyr)
})

source("pipelines/R/silver.R")       # assert_climasus_meta()
source("pipelines/R/gold.R")         # make_health_daily(), make_health_climate_mart(), full_muni_day_grid()
source("pipelines/R/muni_summary.R") # make_muni_mortality_summary()
source("pipelines/R/catalog.R")      # build_catalog()
source("pipelines/R/dashboard_helpers.R") # check_schema_report()

cfg_base <- yaml::read_yaml("pipelines/config/br_full.yaml")

args    <- commandArgs(trailingOnly = TRUE)
ufs     <- if (length(args) >= 1 && nzchar(args[[1]])) strsplit(args[[1]], ",")[[1]] else cfg_base$uf_list
version <- if (length(args) >= 2 && nzchar(args[[2]])) args[[2]] else "1.1.0"
cfg_base$gold$version <- version

cli::cli_h1("health_climate_daily / health_climate_muni_summary -> v{version}")
cli::cli_alert_info("UFs: {paste(ufs, collapse = ', ')}")

#' Lê um dataset Silver já em disco (SIM-DO padronizado ou INMET já
#' preenchido), sem rede — mesmo padrão de run_dlnm.R::read_silver().
read_silver <- function(dataset, cfg) {
  path <- file.path(cfg$paths$silver, dataset, paste0("uf=", cfg$uf), "data.parquet")
  if (!file.exists(path)) {
    cli::cli_abort(
      "Silver ausente em {.path {path}} — rode run_national.R para uf={cfg$uf} primeiro."
    )
  }
  climasus4r:::from_arrow_climasus(path)
}

results <- setNames(character(length(ufs)), ufs)

for (uf in ufs) {
  cli::cli_h2("UF: {uf}")
  cfg <- cfg_base
  cfg$uf <- uf

  result <- tryCatch({
    silver_sim   <- read_silver("sim_do", cfg)
    silver_inmet <- read_silver("inmet_hourly", cfg)

    health_daily <- make_health_daily(silver_sim, cfg)
    make_health_climate_mart(health_daily, silver_inmet, cfg)

    # Lê o health_climate_daily recém-escrito acima (mesma cfg$gold$version)
    # e agrega por município — não reprocessa saúde/clima.
    make_muni_mortality_summary(cfg)

    "ok"
  }, error = function(e) {
    cli::cli_alert_danger("UF {uf} falhou: {conditionMessage(e)}")
    "erro"
  })

  results[[uf]] <- result
  cli::cli_alert_info("UF {uf}: {result}")
}

falhas <- names(results)[results == "erro"]
if (length(falhas) > 0) {
  cli::cli_alert_danger("UF(s) com falha: {paste(falhas, collapse = ', ')} — ver mensagens acima.")
}

build_catalog(cfg_base$paths$public)

# Reaplica o contrato de schema (docs/DATA_MODEL.md) só sobre a versão que
# este script acabou de escrever — não sobre v1.0.0, que fica intocada.
schema_paths <- Sys.glob(file.path(
  cfg_base$paths$public, "gold", "health_climate_daily", paste0("v", version), "uf=*", "data.parquet"
))
if (length(schema_paths) > 0) {
  report <- check_schema_report(schema_paths)
  failed <- report[!report$ok, ]
  if (nrow(failed) > 0) {
    cli::cli_alert_danger(sprintf(
      "Contrato de schema (docs/DATA_MODEL.md) falhou em %d de %d partição(ões):\n%s",
      nrow(failed), nrow(report),
      paste(sprintf("  %s: %s", failed$path, failed$problem), collapse = "\n")
    ))
  } else {
    cli::cli_alert_success("OK: {nrow(report)} partição(ões) de v{version} respeitam o contrato de schema.")
  }
} else {
  cli::cli_alert_warning("Nenhuma partição de v{version} encontrada para checagem de schema — todas as UFs falharam?")
}

if (length(falhas) == 0) {
  cli::cli_alert_success(
    "health_climate_daily / health_climate_muni_summary v{version}: {length(ufs)} UF(s) concluída(s) com sucesso."
  )
} else {
  cli::cli_alert_warning(
    "Concluído com {length(falhas)} falha(s) de {length(ufs)} UF(s) — ver acima."
  )
}
