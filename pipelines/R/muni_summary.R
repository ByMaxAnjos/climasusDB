# Camada Gold — resumo de mortalidade por município (Fase 2c). Agrega o mart
# health_climate_daily já publicado (2018-2023) do grão município x dia para
# o grão município, somando óbitos no período coberto pela partição. Não
# reprocessa saúde/clima — só lê o Gold já materializado e soma; se
# health_climate_daily mudar (nova versão), este dataset precisa ser
# regenerado a partir dela.
# Regra: sempre write_parquet_climasus(); nunca sus_as_arrow()/sus_as_duckdb().
#
# Supressão de célula pequena (k=5): decisão editorial adotada após revisão
# por pares. Aplicada aqui, no grão município (soma do período inteiro), e
# NÃO no grão município-dia de health_climate_daily — suprimir linha a linha
# no grão diário eliminaria quase toda a série (óbitos/dia por município são
# tipicamente 1-4 por natureza, não é uma célula rara), inviabilizando o uso
# do mart diário para modelagem de séries temporais (DLNM etc.), que é sua
# razão de existir. Ver docs/DATA_MODEL.md para a justificativa completa.
.SMALL_CELL_THRESHOLD <- 5L

suppress_small_cell <- function(x, threshold = .SMALL_CELL_THRESHOLD) {
  dplyr::if_else(x > 0 & x < threshold, NA_integer_, x)
}

#' Resume health_climate_daily para o grão município. health_climate_daily
#' não é uma grade diária completa — só há linha para município-dia com
#' >=1 óbito (ver docs/DATA_MODEL.md) — por isso `n_death_days` conta dias
#' com óbito registrado, não dias de calendário, e é documentado como tal.
make_muni_mortality_summary <- function(cfg) {
  daily_path <- file.path(cfg$paths$public, "gold", "health_climate_daily",
                           paste0("v", cfg$gold$version), paste0("uf=", cfg$uf), "data.parquet")
  if (!file.exists(daily_path)) {
    cli::cli_abort(
      "Gold health_climate_daily ausente em {.path {daily_path}} — rode run_national.R para uf={cfg$uf} primeiro."
    )
  }
  daily <- arrow::read_parquet(daily_path)

  summary_df <- daily |>
    dplyr::group_by(code_muni, name_muni) |>
    dplyr::summarise(
      deaths_total = sum(deaths_total, na.rm = TRUE),
      deaths_resp  = sum(deaths_resp,  na.rm = TRUE),
      deaths_circ  = sum(deaths_circ,  na.rm = TRUE),
      n_death_days = dplyr::n(),
      date_start   = min(date, na.rm = TRUE),
      date_end     = max(date, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      uf = cfg$uf,
      deaths_total_suppressed = deaths_total > 0 & deaths_total < .SMALL_CELL_THRESHOLD,
      deaths_resp_suppressed  = deaths_resp  > 0 & deaths_resp  < .SMALL_CELL_THRESHOLD,
      deaths_circ_suppressed  = deaths_circ  > 0 & deaths_circ  < .SMALL_CELL_THRESHOLD,
      deaths_total = suppress_small_cell(deaths_total),
      deaths_resp  = suppress_small_cell(deaths_resp),
      deaths_circ  = suppress_small_cell(deaths_circ),
      .after = name_muni
    ) |>
    dplyr::arrange(dplyr::desc(deaths_total))

  summary_df <- climasus4r:::new_climasus_df(
    summary_df,
    list(system = cfg$health$system, stage = "aggregate", type = "agg")
  )
  summary_df <- climasus4r::sus_meta(
    summary_df,
    user = list(
      synthetic      = FALSE,
      generator      = "pipelines/R/muni_summary.R::make_muni_mortality_summary()",
      uf             = cfg$uf,
      source_dataset = "health_climate_daily",
      source_version = cfg$gold$version
    ),
    add_history = "Per-municipality mortality summary derived from published health_climate_daily Gold mart (Fase 2c)"
  )

  out_dir <- file.path(cfg$paths$public, "gold", "health_climate_muni_summary",
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(summary_df, out_path, chunk_size = cfg$gold$chunk_size)
  assert_climasus_meta(out_path)

  summary_df
}
