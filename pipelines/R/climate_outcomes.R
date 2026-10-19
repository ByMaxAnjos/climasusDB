# Gold SIM por residência; cache Silver já padronizado e filtrado por clima.
CLIMATE_OUTCOMES <- c("cardiovascular", "respiratory_syndrome", "heat_related",
  "cold_exposure", "diarrheal", "dengue", "vector_borne", "malaria",
  "leptospirosis", "diabetes", "mental_disorders", "suicide_self_harm")

make_climate_outcomes <- function(cfg) {
  opt <- cfg$climate_outcomes
  requested <- setdiff(seq.int(opt$year_min, opt$year_max), opt$exclude_years)
  path <- file.path(cfg$paths$silver, "sim_do", paste0("uf=", cfg$uf), "data.parquet")
  if (!file.exists(path)) stop("Cache SIM ausente: ", path)
  sim <- climasus4r:::from_arrow_climasus(path)
  required <- c("data_obito", "codigo_municipio_residencia", "causa_basica")
  stopifnot(all(required %in% names(sim)))
  available <- sort(unique(as.integer(format(sim$data_obito, "%Y"))))
  years <- intersect(requested, available)
  if (!length(years)) stop("Nenhum ano solicitado disponível no cache")
  missing <- setdiff(requested, years)
  if (length(missing)) warning("Janela parcial; anos ausentes: ", paste(missing, collapse = ","))
  groups <- climasus4r:::list_disease_groups(climate_sensitive_only = TRUE)
  group_names <- if (is.character(groups)) groups else unlist(groups[[1]])
  if (!all(CLIMATE_OUTCOMES %in% group_names)) stop("Grupos CID divergentes da spec")
  muni <- arrow::read_parquet(system.file("data_4r", "municipio_meta.parquet", package = "climasus4r")) |>
    dplyr::filter(uf_code == cfg$uf) |>
    dplyr::transmute(code_muni = as.integer(municipio), datasus = code_muni %/% 10L)
  raw_code <- suppressWarnings(as.integer(as.character(sim$codigo_municipio_residencia)))
  code <- ifelse(raw_code >= 1000000L, raw_code, muni$code_muni[match(raw_code, muni$datasus)])
  valid <- code %in% muni$code_muni & as.integer(format(sim$data_obito, "%Y")) %in% years
  dropped <- sum(!code %in% muni$code_muni)
  # Retira colunas alternativas para impedir prioridade de ocorrência do pacote.
  sim$codigo_municipio_residencia <- as.integer(code)
  sim <- sim[valid, , drop = FALSE]
  geo <- grep("municip|CODMUN|MUNI_", names(sim), value = TRUE, ignore.case = TRUE)
  sim <- sim[, setdiff(names(sim), setdiff(geo, "codigo_municipio_residencia")), drop = FALSE]
  counts <- lapply(CLIMATE_OUTCOMES, function(outcome) {
    selected <- climasus4r::sus_data_filter_cid(sim, disease_group = outcome, backend = "tibble")
    if (!nrow(selected)) return(tibble::tibble(code_muni = integer(), year = integer(), outcome = character(), n_events = integer()))
    agg <- climasus4r::sus_data_aggregate(selected, time_unit = "year", fun = "count",
      date_col = "data_obito", complete_dates = FALSE, backend = "tibble", lang = "en", verbose = FALSE)
    dplyr::transmute(agg, code_muni = as.integer(codigo_municipio_residencia),
      year = as.integer(format(date, "%Y")), outcome = outcome, n_events = as.integer(n_deaths))
  }) |> dplyr::bind_rows()
  gold <- tidyr::expand_grid(code_muni = muni$code_muni, year = years, outcome = CLIMATE_OUTCOMES) |>
    dplyr::left_join(counts, by = c("code_muni", "year", "outcome")) |>
    dplyr::mutate(n_events = dplyr::coalesce(n_events, 0L), system = "SIM", sex = "all", age_group = "all")
  # Contrato offline: população anual IBGE validada, uma linha por município/ano.
  pop_path <- opt$population_path
  if (!is.null(pop_path) && file.exists(pop_path)) {
    pop <- arrow::read_parquet(pop_path)
    stopifnot(all(c("code_muni", "year", "population", "pop_source") %in% names(pop)),
      !anyDuplicated(pop[c("code_muni", "year")]),
      all(!is.na(pop$population) & pop$population > 0 & pop$population == as.integer(pop$population)),
      all(grepl("IBGE", pop$pop_source, ignore.case = TRUE)))
    gold <- dplyr::left_join(gold, pop[c("code_muni", "year", "population", "pop_source")], by = c("code_muni", "year"))
  } else {
    warning("Denominador anual IBGE indisponível: população e taxas serão NA")
    gold$population <- NA_integer_
    gold$pop_source <- NA_character_
  }
  gold <- gold |>
    dplyr::mutate(population = as.integer(population), suppressed = n_events > 0L & n_events < 5L,
      n_events = dplyr::if_else(suppressed, NA_integer_, n_events),
      rate_100k = dplyr::if_else(!suppressed & !is.na(population) & population >= 1000L,
        n_events / population * 1e5, NA_real_), rate_100k_std = NA_real_) |>
    dplyr::select(code_muni, year, system, outcome, sex, age_group, n_events, suppressed,
      population, rate_100k, rate_100k_std, pop_source) |>
    dplyr::arrange(code_muni, year, outcome, sex, age_group)
  gold <- climasus4r:::new_climasus_df(gold, list(system = "SIM-DO", stage = "aggregated", type = "munic"))
  gold <- climasus4r::sus_meta(gold, user = list(synthetic = FALSE, uf = cfg$uf,
    generator = "pipelines/R/run_climate_outcomes.R", years = years, requested_years = requested,
    missing_years = missing, outcomes = CLIMATE_OUTCOMES, geography = "residence",
    suppression_k = 5L, population_source = "IBGE annual cache; missing denominators are NA",
    package_version = as.character(utils::packageVersion("climasus4r")), dropped_residence = dropped))
  out <- file.path(cfg$paths$public, "gold", "climate_outcomes_muni_year", paste0("v", cfg$gold$version), paste0("uf=", cfg$uf), "data.parquet")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  climasus4r::write_parquet_climasus(gold, out, compression = "zstd", chunk_size = 1e5)
  assert_climasus_meta(out)
  out
}
