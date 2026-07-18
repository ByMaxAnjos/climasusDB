# Camada Bronze — download bruto, cacheado e retomável.
# Wrappers finos sobre climasus4r; nenhuma transformação além do que o
# pacote já faz (cache em disco por parâmetros, paralelismo, fallback tibble).

#' @param cfg lista carregada de pipelines/config/ro_mvp.yaml
#
# parallel=FALSE em ambos: o default do pacote (4 workers) assume CPUs
# dedicadas; em containers com cota de CPU (cgroup), parallelly detecta
# "1 core efetivo" e recusa abrir workers, travando o download inteiro
# (mesmo com rede OK). Sequencial é mais lento mas sempre funciona.
#
# backend="tibble" em get_bronze_sim(): o default "arrow" retorna um dataset
# LAZY com ponteiro externo (objeto C++ do Arrow). O {targets} serializa
# cada target em disco entre execuções — ponteiros externos não sobrevivem a
# essa serialização e voltam nulos na próxima run ("external pointer to
# null"), quebrando toda a cadeia. RO é pequeno o bastante para materializar
# (eager) sem custo de memória relevante.
#
# Import ANO A ANO (não um vetor de anos numa só chamada): internamente
# sus_data_import() combina múltiplos anos com
# data.table::rbindlist(fill=FALSE) — quando o layout de colunas do DATASUS
# muda entre releases anuais (ex.: 87 vs 88 colunas em SIM-DO 2018-2023),
# essa combinação erra. Fazendo uma chamada por ano e combinando aqui com
# dplyr::bind_rows() (que preenche colunas ausentes com NA), o pipeline
# sobrevive à inconsistência de schema entre anos do DATASUS.
get_bronze_sim <- function(cfg) {
  per_year <- lapply(cfg$years, function(yr) {
    climasus4r::sus_data_import(
      uf        = cfg$uf,
      year      = yr,
      system    = cfg$health$system,
      cache_dir = file.path(cfg$paths$bronze, "datasus"),
      parallel  = FALSE,
      backend   = "tibble"
    )
  })

  meta <- climasus4r::sus_meta(per_year[[1]])
  combined <- dplyr::bind_rows(per_year)
  combined <- climasus4r:::new_climasus_df(combined, meta)
  climasus4r::sus_meta(
    combined,
    add_history = sprintf("Combined %d yearly imports (bind_rows, fill NA on schema drift)", length(per_year))
  )
}

#' Lê SIM-DO já baixado por inst/scripts/create_national_database.R (do
#' pacote climasus4r) em vez de baixar via rede — usado por
#' run_national_from_cache.R quando o bronze já existe localmente (ex.:
#' copiado de outra máquina). Layout Hive dessa saída (diferente do cache
#' interno do climasus4r, que é um diretório plano de `{cache_key}.parquet`):
#'   {cache_root}/sim/DO/uf=XX/year=YYYY/data.parquet
#' Lê ano a ano e faz bind_rows() pelo mesmo motivo de get_bronze_sim(): o
#' layout de colunas do DATASUS muda entre releases anuais.
get_bronze_sim_from_cache <- function(cfg, cache_root) {
  per_year <- lapply(cfg$years, function(yr) {
    path <- file.path(cache_root, "sim", "DO", paste0("uf=", cfg$uf), paste0("year=", yr), "data.parquet")
    if (!file.exists(path)) {
      cli::cli_alert_warning("Sem cache local para uf={cfg$uf} ano={yr} em {path} — pulando (ver manifest.csv)")
      return(NULL)
    }
    arrow::read_parquet(path)
  })
  per_year <- Filter(Negate(is.null), per_year)
  if (length(per_year) == 0) {
    cli::cli_abort("Nenhum ano em cache local para uf={cfg$uf} (esperado em {cache_root}/sim/DO/uf={cfg$uf}/)")
  }

  combined <- dplyr::bind_rows(per_year)
  combined <- climasus4r:::new_climasus_df(combined, list(system = cfg$health$system, stage = "import"))
  climasus4r::sus_meta(
    combined,
    add_history = sprintf(
      "Loaded %d yearly file(s) from local DATASUS cache (%s), no network — see create_national_database.R",
      length(per_year), cache_root
    )
  )
}

get_bronze_inmet <- function(cfg) {
  climasus4r::sus_climate_inmet(
    years     = cfg$years,
    uf        = cfg$uf,
    cache_dir = file.path(cfg$paths$bronze, "inmet"),
    parallel  = FALSE
  )
}

# Estações automáticas do INMET falham com frequência (sensor, transmissão,
# manutenção) — sem preenchimento, uma fração grande do mart final fica com
# clima ausente (ver docs/PLANO.md, limitação conhecida do dataset RO:
# ~49% NA com só 7 estações). sus_climate_fill_inmet() imputa por XGBoost
# station-wise sobre a saída de sus_climate_inmet() (bronze_inmet), antes de
# qualquer coisa consumir a série — silver, mart e detecção de ondas de
# calor devem receber o resultado desta função, não o bronze bruto.
# parallel=FALSE pelo mesmo motivo do bug #5 (cgroup CPU quota rejeita
# workers do `parallelly` em containers, mesmo com CPUs livres).
fill_bronze_inmet <- function(bronze_inmet, cfg) {
  climasus4r::sus_climate_fill_inmet(
    bronze_inmet,
    target_var = cfg$climate$climate_vars,
    parallel   = FALSE
  )
}
