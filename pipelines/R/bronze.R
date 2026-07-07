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

get_bronze_inmet <- function(cfg) {
  climasus4r::sus_climate_inmet(
    years     = cfg$years,
    uf        = cfg$uf,
    cache_dir = file.path(cfg$paths$bronze, "inmet"),
    parallel  = FALSE
  )
}
