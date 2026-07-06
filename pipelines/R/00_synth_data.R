#!/usr/bin/env Rscript
# Gerador de dados SINTÉTICOS para o scaffold da Fase 0 do climasusDB.
#
# Roda 100% offline: usa apenas a dimensão `municipio_meta.parquet` embutida no
# pacote climasus4r (sem download de DATASUS/INMET). Produz o mart
# `health_climate_daily` para Rondônia com o schema exato de docs/DATA_MODEL.md,
# para que o pipeline real (01_ro_gold.R) possa substituí-lo sem exigir
# nenhuma mudança no frontend.
#
# Uso: Rscript pipelines/R/00_synth_data.R

suppressPackageStartupMessages({
  library(climasus4r)
  library(arrow)
  library(dplyr)
  library(tidyr)
})

set.seed(42)

# ---- 1. Dimensão de municípios de RO (offline, embutida no pacote) --------

muni_meta_path <- system.file("data_4r", "municipio_meta.parquet", package = "climasus4r")
if (identical(muni_meta_path, "")) {
  stop("Não encontrei inst/data_4r/municipio_meta.parquet no climasus4r instalado. ",
       "Instale o pacote local: remotes::install_local('../climasus4r')")
}

muni <- read_parquet(muni_meta_path) |>
  filter(uf_code == "RO") |>
  transmute(
    code_muni = as.integer(municipio),
    name_muni = name
  )

stopifnot(nrow(muni) == 52)
cli::cli_inform("Municípios de RO carregados: {nrow(muni)}")

# ---- 2. Grade município x dia (2 anos) -------------------------------------

dates <- seq(as.Date("2022-01-01"), as.Date("2023-12-31"), by = "day")

grid <- tidyr::crossing(muni, date = dates)

doy <- as.integer(format(grid$date, "%j"))
n <- nrow(grid)

gold <- grid |>
  mutate(
    # Sazonalidade amazônica: pico de temperatura por volta de setembro/outubro
    tmean  = 26 + 2.5 * sin(2 * pi * (doy - 200) / 365) + rnorm(n, 0, 1.2),
    tmax   = tmean + runif(n, 3, 7),
    tmin   = tmean - runif(n, 2, 5),
    # Estação chuvosa (dez-mar, doy < 120 | doy > 300) vs seca
    precip = ifelse(doy < 120 | doy > 300,
                     rgamma(n, shape = 2, rate = 0.15),
                     rgamma(n, shape = 0.5, rate = 0.3)),
    rh     = pmin(100, pmax(20, 75 + 10 * sin(2 * pi * (doy - 30) / 365) + rnorm(n, 0, 5))),
    # Mortalidade ~ Poisson com efeito de calor acima de 33C (sinal visível no atlas)
    deaths_total = rpois(n, lambda = 0.8 * exp(0.03 * pmax(0, tmax - 33))),
    deaths_resp  = rbinom(n, deaths_total, 0.35),
    deaths_circ  = rbinom(n, deaths_total, 0.40)
  ) |>
  arrange(code_muni, date) |>
  select(code_muni, name_muni, date, deaths_total, deaths_resp, deaths_circ,
         tmean, tmax, tmin, precip, rh)

cli::cli_inform("Linhas geradas: {nrow(gold)} ({nrow(muni)} municípios x {length(dates)} dias)")

# ---- 3. Persistir com proveniência (write_parquet_climasus) ---------------

# new_climasus_df() é interna (não exportada) — write_parquet_climasus() exige
# um climasus_df e o pacote não expõe um construtor público para tibbles
# comuns, então usamos climasus4r::: aqui (é o próprio pacote que orquestramos).
gold_climasus <- climasus4r:::new_climasus_df(
  gold,
  list(system = "SIM", stage = "aggregate", type = "agg")
)
gold_climasus <- sus_meta(
  gold_climasus,
  user        = list(synthetic = TRUE, generator = "00_synth_data.R", uf = "RO"),
  add_history = "Synthetic data generated for climasusDB Phase 0 scaffold"
)

out_dir <- file.path("data", "public", "gold", "health_climate_daily", "v0.1.0", "uf=RO")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, "data.parquet")

write_parquet_climasus(gold_climasus, out_path, chunk_size = 1e5)

# ---- 4. Catálogo raiz mínimo ------------------------------------------------

catalog <- list(
  datasets = list(
    list(
      name    = "health_climate_daily",
      latest  = "v0.1.0",
      synthetic = TRUE,
      path    = "gold/health_climate_daily/v0.1.0/uf=RO/data.parquet",
      rows    = nrow(gold),
      columns = names(gold)
    )
  )
)
jsonlite::write_json(catalog, file.path("data", "public", "catalog.json"),
                     auto_unbox = TRUE, pretty = TRUE)

# ---- 5. Validação (aceite A) ------------------------------------------------

check <- arrow::open_dataset(out_path)
stopifnot(nrow(check) == 52 * length(dates))
meta_json <- check$schema$metadata[["climasus_meta"]]
stopifnot(!is.null(meta_json))

cli::cli_alert_success("Aceite A OK: {out_path} com {nrow(check)} linhas e metadados climasus_meta embutidos.")
