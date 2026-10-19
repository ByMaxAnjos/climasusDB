#!/usr/bin/env Rscript
# Fase 3 — guarda de privacidade antes de cunhar DOI: sinaliza células
# município x dia com contagem pequena (risco de reidentificação em óbitos
# raros), conforme docs/PLANO.md ("supressão de células pequenas antes do
# DOI"). Não suprime automaticamente — decisão editorial é do time do
# climaSUS; este script só reporta o que precisa de revisão.
#
# Uso: Rscript pipelines/R/check_small_cells.R [threshold] [path]

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(cli)
})

args <- commandArgs(trailingOnly = TRUE)
threshold <- if (length(args) >= 1) as.integer(args[[1]]) else 5L
path <- if (length(args) >= 2) args[[2]] else
  "data/public/gold/health_climate_daily/v0.1.0/uf=RO/data.parquet"

ds <- arrow::open_dataset(path)
if ("n_events" %in% names(ds$schema)) {
  if (threshold != 5L) stop("climate_outcomes exige k=5")
  x <- ds |> collect()
  bad <- is.na(x$suppressed) | (!is.na(x$n_events) & x$n_events < 0L) |
    (!is.na(x$n_events) & x$n_events > 0L & x$n_events < 5L) |
    (x$suppressed & (!is.na(x$n_events) | !is.na(x$rate_100k) | !is.na(x$rate_100k_std))) |
    (!x$suppressed & is.na(x$n_events))
  if (any(bad)) stop("Supressão inválida em ", sum(bad), " células")
  cat("OK: k=5; ", sum(x$suppressed), " células suprimidas\n", sep="")
  quit(status=0L)
}
small <- ds |>
  filter(deaths_total > 0 & deaths_total < threshold) |>
  count(code_muni, name = "n_small_cells") |>
  collect() |>
  arrange(desc(n_small_cells))

total_rows <- ds |> count() |> collect() |> pull(n)

cli::cli_h1("Relatório de células pequenas — {path}")
cli::cli_alert_info("Limiar: contagens de 1 a {threshold - 1}")
cli::cli_alert_info("Linhas totais: {total_rows}")
cli::cli_alert_warning("Municípios com células pequenas: {nrow(small)}")
if (nrow(small) > 0) {
  print(small)
  cli::cli_alert_warning(paste(
    "Antes de publicar com DOI, revisar se a soma por período mais longo",
    "(ex.: semanal/mensal) ou a supressão dessas células é necessária."
  ))
} else {
  cli::cli_alert_success("Nenhuma célula abaixo do limiar — dataset ok para publicação.")
}
