# Camada Silver — padronização, ainda no grão registro. Toda saída passa por
# write_parquet_climasus() (nunca sus_as_arrow()/sus_as_duckdb() — chave de
# metadados incompatível, ver docs/DATA_MODEL.md) e é validada com
# assert_climasus_meta() antes de seguir para a Gold.

assert_climasus_meta <- function(path) {
  ds <- arrow::open_dataset(path)
  meta <- ds$schema$metadata[["climasus_meta"]]
  if (is.null(meta)) {
    cli::cli_abort("Parquet sem metadados climasus_meta: {.path {path}}")
  }
  invisible(TRUE)
}

make_silver_sim <- function(bronze_sim, cfg) {
  # backend="tibble" em CADA etapa: clean_encoding/standardize/filter_cid têm
  # cada uma seu próprio parâmetro `backend` (default "arrow", lazy),
  # independente do backend passado ao import — sem repetir aqui, a saída
  # vira um arrow_dplyr_query lazy (não climasus_df) e write_parquet_climasus
  # aborta com "`x` must be a <climasus_df> object".
  silver <- bronze_sim |>
    climasus4r::sus_data_clean_encoding(backend = "tibble") |>
    climasus4r::sus_data_standardize(backend = "tibble") |>
    climasus4r::sus_data_filter_cid(disease_group = cfg$health$disease_group, backend = "tibble")

  out_dir <- file.path(cfg$paths$silver, "sim_do", paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(silver, out_path)
  assert_climasus_meta(out_path)

  silver
}

make_silver_inmet <- function(bronze_inmet, cfg) {
  out_dir <- file.path(cfg$paths$silver, "inmet_hourly", paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(bronze_inmet, out_path)
  assert_climasus_meta(out_path)

  bronze_inmet
}
