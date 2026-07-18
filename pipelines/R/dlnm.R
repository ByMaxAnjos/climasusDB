# Camada de modelagem — risco relativo por DLNM (Distributed Lag Non-linear
# Model), um modelo por UF. Reaproveita 100% do que já está em disco
# (silver_sim, silver_inmet já preenchido por fill_bronze_inmet()) — nenhum
# novo download do DATASUS/INMET é feito aqui.
#
# Por que um script separado de gold.R: sus_mod_dlnm() (climasus4r) exige um
# climasus_df em stage="climate"/type="distributed_lag" (colunas
# {climate_var}_lag0..lagN), mas o mart publicado (health_climate_daily) usa
# temporal_strategy="exact" (sem colunas de lag) — os dois formatos servem a
# propósitos diferentes e não dá pra derivar um do outro sem reprocessar o
# join espacial saúde x clima.
#
# Por que 1 modelo por UF, não por município: a maioria dos 5.570 municípios
# brasileiros tem 0-1 óbito/dia nos grupos climate-sensitive — instável
# demais para um DLNM individual. Agregado por UF (o que sus_mod_dlnm() já
# faz sozinho, somando óbitos e tirando média do clima por dia) dá uma série
# longa (2018-2023) com contagem diária suficiente para estabilidade
# estatística, na mesma granularidade Hive (uf=XX) do resto do catálogo.
#
# Dois datasets Gold novos:
#   - health_climate_distributed_lag: a série de exposição com colunas de
#     lag, ANTES do ajuste do modelo — publicada para reuso por qualquer
#     outra modelagem (não só DLNM) que precise de exposição defasada.
#   - dlnm_exposure_response / dlnm_lag_response / dlnm_surface: a saída do
#     DLNM em si — curva de risco relativo x percentil de exposição, curva
#     de risco relativo x lag (na exposição do p75), e a superfície completa
#     exposição x lag (para o heatmap) —, grão UF x percentil / UF x lag /
#     UF x exposição x lag.

make_distributed_lag_mart <- function(health_daily, silver_inmet, cfg) {
  health_climasus <- build_health_sf(health_daily, cfg)

  dl <- climasus4r::sus_climate_aggregate(
    health_data       = health_climasus,
    climate_data      = silver_inmet,
    climate_var       = cfg$dlnm$climate_var,
    time_unit         = "day",
    temporal_strategy = "distributed_lag",
    lag_days          = cfg$dlnm$lag_days
  )

  # sus_climate_aggregate(temporal_strategy="distributed_lag") devolve um
  # objeto que perdeu a classe "sf" mas manteve a coluna `geometry` (lista
  # sfc) órfã — sf::st_drop_geometry() não faz nada porque a classe já não é
  # "sf", e o Arrow trava na gravação ("NotImplemented: extension") ao tentar
  # serializar essa coluna. dplyr::select() remove a coluna direto, sem
  # depender da classe do objeto.
  dl <- dl |>
    dplyr::select(-dplyr::any_of("geometry")) |>
    dplyr::arrange(code_muni, date)

  dl <- climasus4r::sus_meta(
    dl,
    user = list(synthetic = FALSE, generator = "pipelines/R/dlnm.R", uf = cfg$uf)
  )

  out_dir <- file.path(cfg$paths$public, "gold", "health_climate_distributed_lag",
                        paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, "data.parquet")
  climasus4r::write_parquet_climasus(dl, out_path, chunk_size = cfg$gold$chunk_size)
  assert_climasus_meta(out_path)

  dl
}

#' Ajusta 1 DLNM para a UF (agregação diária feita pelo próprio
#' sus_mod_dlnm()) e publica a curva exposição-resposta e a curva de lag.
#' Retorna o objeto climasus_dlnm inteiro (não só o que foi escrito), para
#' quem quiser inspecionar diagnostics/model/crossbasis interativamente.
make_dlnm_relative_risk <- function(distributed_lag_mart, cfg) {
  fit <- climasus4r::sus_mod_dlnm(
    df          = distributed_lag_mart,
    outcome_col = cfg$dlnm$outcome_col,
    climate_col = cfg$dlnm$climate_var,
    lag_max     = cfg$dlnm$lag_days,
    family      = cfg$dlnm$family,
    lang        = "en",
    verbose     = FALSE
  )

  write_dlnm_dataset <- function(df, name) {
    # disp_ratio/has_autocorr também como COLUNA (não só em climasus_meta):
    # o frontend consulta via DuckDB-WASM, que não lê metadados de schema
    # Arrow linha a linha — precisa ser um valor de dado pra virar aviso de
    # UI por UF (ver docs/DATA_MODEL.md, achado de autocorrelação residual).
    df <- df |>
      dplyr::mutate(
        uf            = cfg$uf,
        disp_ratio    = round(fit$diagnostics$disp_ratio, 3),
        has_autocorr  = fit$diagnostics$has_autocorr,
        .before = 1
      )
    dfc <- climasus4r:::new_climasus_df(
      df, list(system = cfg$health$system, stage = "climate", type = "dlnm_model")
    )
    dfc <- climasus4r::sus_meta(
      dfc,
      user = list(
        synthetic       = FALSE,
        generator       = "pipelines/R/dlnm.R",
        uf              = cfg$uf,
        dlnm_climate_var = cfg$dlnm$climate_var,
        dlnm_lag_days   = cfg$dlnm$lag_days,
        dlnm_family     = fit$meta$family,
        dlnm_n_obs      = fit$meta$n,
        dlnm_disp_ratio = round(fit$diagnostics$disp_ratio, 3),
        dlnm_has_autocorr = fit$diagnostics$has_autocorr
      )
    )
    out_dir <- file.path(cfg$paths$public, "gold", name,
                          paste0("v", cfg$gold$version), paste0("uf=", cfg$uf))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    out_path <- file.path(out_dir, "data.parquet")
    climasus4r::write_parquet_climasus(dfc, out_path)
    assert_climasus_meta(out_path)
  }

  write_dlnm_dataset(.dlnm_exposure_response_full_tbl(fit), "dlnm_exposure_response")
  write_dlnm_dataset(fit$lag_response, "dlnm_lag_response")
  write_dlnm_dataset(.dlnm_surface_tbl(fit), "dlnm_surface")

  fit
}

#' Curva exposição-resposta em grade fina (100 pontos, fit$pred$predvar),
#' não só os 6 percentis de fit$exposure_response — é a mesma curva usada
#' por climasus4r:::.plot_dlnm_overall() no pacote R, aqui publicada como
#' dado para o gráfico "overall" do Explore desenhar uma linha suave com
#' faixa de IC. A coluna `pct` marca o ponto de grade mais próximo de cada
#' percentil reportado por sus_mod_dlnm() (NA nos demais), pra destacar os
#' mesmos marcadores do gráfico R sem recalcular percentil no cliente.
.dlnm_exposure_response_full_tbl <- function(fit) {
  exp_vec <- as.numeric(fit$pred$predvar)
  full <- tibble::tibble(
    exposure = round(exp_vec, 3L),
    rr       = as.numeric(fit$pred$allRRfit),
    lo       = as.numeric(fit$pred$allRRlow),
    hi       = as.numeric(fit$pred$allRRhigh),
    pct      = NA_real_
  )
  er <- fit$exposure_response
  for (i in seq_len(nrow(er))) {
    idx <- which.min(abs(full$exposure - er$exposure[i]))
    full$pct[idx] <- er$pct[i]
  }
  full
}

#' Achata a superfície bidimensional exposição x lag (fit$pred$matRRfit, uma
#' matriz [n_exposure x n_lag]) em formato longo — mesma transformação que
#' climasus4r usa internamente em .plot_dlnm_contour()/.plot_dlnm_surface(),
#' só que aqui vira dado publicável (grão UF x exposição x lag) em vez de um
#' gráfico R, pro heatmap do Explore consumir via SQL.
.dlnm_surface_tbl <- function(fit) {
  lag_seq <- as.integer(seq(fit$pred$lag[1L], fit$pred$lag[2L]))
  exp_vec <- as.numeric(fit$pred$predvar)
  rr_mat  <- fit$pred$matRRfit # linhas = exposição, colunas = lag

  tibble::tibble(
    exposure = rep(round(exp_vec, 3L), times = length(lag_seq)),
    lag      = rep(lag_seq, each = length(exp_vec)),
    rr       = as.vector(rr_mat)
  )
}
