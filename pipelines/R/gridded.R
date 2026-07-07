# Fase 2 — fontes de clima em grade (sem API key), complementares ao INMET
# em áreas com baixa densidade de estações. Cada wrapper devolve um
# climasus_df agregado por município (via exactextractr, já embutido nas
# funções sus_grid_*), persistido pela mesma regra (write_parquet_climasus).

get_gridded_era5 <- function(cfg) {
  climasus4r::sus_grid_era5(
    years = cfg$years,
    uf    = cfg$uf
  )
}

get_gridded_chirps <- function(cfg) {
  climasus4r::sus_grid_chirps(
    years = cfg$years,
    uf    = cfg$uf
  )
}

#' Escreve um dataset gridded como Gold complementar (não é o mart principal).
make_gridded_gold <- function(df, dataset_name, cfg) {
  out_dir <- file.path(cfg$paths$public, "gold", dataset_name,
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(df, out_path, chunk_size = cfg$gold$chunk_size)
  assert_climasus_meta(out_path)
  df
}
