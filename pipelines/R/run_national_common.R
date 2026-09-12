# Loop bronze→silver→gold, uma UF por vez — compartilhado por run_national.R
# (SIM-DO via rede) e run_national_from_cache.R (SIM-DO de um bronze local já
# baixado). A única diferença entre os dois pipelines é de onde vem
# `bronze_sim`; tudo o resto (INMET, silver, mart, heatwaves, dim_station) é
# idêntico, então mora aqui uma vez só.

#' @param cfg_base config base (lido de br_full.yaml), sem `uf` definido
#' @param ufs vetor de siglas de UF a processar
#' @param get_bronze_sim_fn function(cfg) -> bronze_sim para a UF de `cfg$uf`
run_national_pipeline <- function(cfg_base, ufs, get_bronze_sim_fn) {
  for (uf in ufs) {
    cli::cli_h1("UF: {uf}")
    cfg <- cfg_base
    cfg$uf <- uf # os wrappers de bronze/silver/gold já são parametrizados por cfg$uf

    result <- tryCatch({
      bronze_sim   <- get_bronze_sim_fn(cfg)
      bronze_inmet <- get_bronze_inmet(cfg)
      # sus_climate_fill_inmet() ANTES de qualquer consumo da série INMET —
      # silver, mart e heatwaves usam a versão preenchida, não o bronze bruto
      # (ver comentário em bronze.R::fill_bronze_inmet()).
      filled_inmet <- fill_bronze_inmet(bronze_inmet, cfg)
      silver_sim   <- make_silver_sim(bronze_sim, cfg)
      silver_inmet <- make_silver_inmet(filled_inmet, cfg)
      health_daily <- make_health_daily(silver_sim, cfg)
      make_health_climate_mart(health_daily, silver_inmet, cfg)
      make_heatwave_events(filled_inmet, cfg)
      make_dim_station(cfg) # sem rede (station_meta.parquet embutido)
      "ok"
    }, error = function(e) {
      cli::cli_alert_danger("UF {uf} falhou: {conditionMessage(e)}")
      "erro"
    })

    cli::cli_alert_info("UF {uf}: {result}")
  }
}
