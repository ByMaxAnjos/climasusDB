#!/usr/bin/env Rscript
# ==============================================================================
# Case Study 6: Biome-Specific Thermal Risk Heterogeneity in Brazil
# Using climasusDB v1.0.0 -- dlnm_exposure_response Gold dataset
#
# Question: do populations in hotter biomes show lower marginal heat
# sensitivity (acclimatisation) or higher sensitivity (accumulated
# vulnerability)? Tested via the shape/peak of the DLNM exposure-response
# curve across Brazil's five major biomes.
#
# Run from the project root: Rscript case_study_6_biome_thermal_risk.R
# ==============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
  library(purrr)
  library(boot)
  library(ggrepel)
})

options(warn = 1) # print warnings as they occur, do not suppress

dir.create("figures", showWarnings = FALSE)
dir.create("tables", showWarnings = FALSE)

GOLD_DIR <- "data/public/gold/dlnm_exposure_response/v1.0.0"
CATALOG_PATH <- "data/public/catalog.json"

BIOME_PALETTE <- c(
  "Amazônia"       = "#2D6A4F",
  "Cerrado"        = "#B7950B",
  "Caatinga"       = "#A93226",
  "Mata Atlântica" = "#1A5276",
  "Pampa"          = "#6C3483"
)

biome_lookup <- tibble::tribble(
  ~uf, ~state_name,            ~biome,
  "AC", "Acre",                 "Amazônia",
  "AM", "Amazonas",             "Amazônia",
  "AP", "Amapá",                "Amazônia",
  "PA", "Pará",                 "Amazônia",
  "RO", "Rondônia",             "Amazônia",
  "RR", "Roraima",              "Amazônia",
  "TO", "Tocantins",            "Cerrado",
  "MA", "Maranhão",             "Cerrado",
  "PI", "Piauí",                "Caatinga",
  "CE", "Ceará",                "Caatinga",
  "RN", "Rio Grande do Norte",  "Caatinga",
  "PB", "Paraíba",              "Caatinga",
  "PE", "Pernambuco",           "Caatinga",
  "AL", "Alagoas",              "Caatinga",
  "SE", "Sergipe",              "Caatinga",
  "BA", "Bahia",                "Caatinga",
  "MT", "Mato Grosso",          "Cerrado",
  "MS", "Mato Grosso do Sul",   "Cerrado",
  "GO", "Goiás",                "Cerrado",
  "DF", "Distrito Federal",     "Cerrado",
  "MG", "Minas Gerais",         "Mata Atlântica",
  "ES", "Espírito Santo",       "Mata Atlântica",
  "RJ", "Rio de Janeiro",       "Mata Atlântica",
  "SP", "São Paulo",            "Mata Atlântica",
  "PR", "Paraná",               "Mata Atlântica",
  "SC", "Santa Catarina",       "Mata Atlântica",
  "RS", "Rio Grande do Sul",    "Pampa"
)

# ------------------------------------------------------------------------
# Step 1 -- Read the Gold dataset (catalog.json first, glob fallback)
# ------------------------------------------------------------------------

read_dlnm_gold <- function(gold_dir, catalog_path) {
  partitions <- NULL

  if (file.exists(catalog_path)) {
    partitions <- tryCatch({
      cat_json <- jsonlite::fromJSON(catalog_path, simplifyDataFrame = FALSE)
      ds <- Filter(function(d) identical(d$name, "dlnm_exposure_response"), cat_json$datasets)
      if (length(ds) == 0) stop("dlnm_exposure_response not found in catalog.json")
      ds <- ds[[1]]
      paths <- vapply(ds$partitions, function(p) p$path, character(1))
      file.path("data/public", paths)
    }, error = function(e) {
      warning(sprintf("catalog.json read failed (%s) -- falling back to direct glob.", conditionMessage(e)))
      NULL
    })
  } else {
    warning("catalog.json not found -- falling back to direct glob.")
  }

  if (is.null(partitions) || length(partitions) == 0) {
    partitions <- Sys.glob(file.path(gold_dir, "uf=*", "data.parquet"))
  }

  if (length(partitions) == 0) {
    stop("No dlnm_exposure_response partitions found via catalog.json or glob.")
  }

  frames <- list()
  failed_ufs <- character(0)
  for (p in partitions) {
    uf_guess <- sub(".*uf=([A-Za-z]{2}).*", "\\1", p)
    df <- tryCatch(arrow::read_parquet(p), error = function(e) {
      warning(sprintf("Failed to read partition for uf=%s (%s) -- skipping, continuing with remaining states.",
                       uf_guess, conditionMessage(e)))
      failed_ufs <<- c(failed_ufs, uf_guess)
      NULL
    })
    if (!is.null(df)) frames[[uf_guess]] <- df
  }

  if (length(failed_ufs) > 0) {
    warning(sprintf("Missing/unreadable state partitions: %s (%d of %d expected).",
                     paste(failed_ufs, collapse = ", "), length(failed_ufs), length(partitions)))
  }

  out <- dplyr::bind_rows(frames)
  cat(sprintf("Loaded dlnm_exposure_response: %d rows, %d states.\n", nrow(out), dplyr::n_distinct(out$uf)))
  out
}

dlnm <- read_dlnm_gold(GOLD_DIR, CATALOG_PATH)

missing_states <- setdiff(biome_lookup$uf, unique(dlnm$uf))
if (length(missing_states) > 0) {
  warning(sprintf("States present in biome lookup but absent from data: %s",
                   paste(missing_states, collapse = ", ")))
}

dlnm <- dlnm |> dplyr::left_join(biome_lookup, by = "uf")

# ------------------------------------------------------------------------
# Step 2 -- Biome-level summaries
# ------------------------------------------------------------------------

# State-level metrics
state_median_temp <- dlnm |>
  dplyr::filter(pct == 0.50) |>
  dplyr::transmute(uf, median_temp_c = exposure)

state_peak <- dlnm |>
  dplyr::group_by(uf) |>
  dplyr::slice_max(order_by = rr, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::transmute(uf, temp_at_peak_c = exposure, peak_rr = rr, peak_lo = lo, peak_hi = hi)

state_flags <- dlnm |>
  dplyr::distinct(uf, biome, state_name, disp_ratio, has_autocorr)

state_summary <- state_flags |>
  dplyr::left_join(state_median_temp, by = "uf") |>
  dplyr::left_join(state_peak, by = "uf") |>
  dplyr::mutate(
    ci_excludes_1 = peak_lo > 1,
    peak_direction = ifelse(temp_at_peak_c < median_temp_c, "cold", "heat")
  ) |>
  dplyr::arrange(biome, uf)

readr_write_csv <- function(x, path) {
  x |> dplyr::mutate(dplyr::across(where(is.numeric), ~round(.x, 2))) |> write.csv(path, row.names = FALSE)
}
readr_write_csv(state_summary, "tables/table_state_biome.csv")

iqr_str <- function(x) {
  q <- stats::quantile(x, c(0.25, 0.75), na.rm = TRUE, names = FALSE)
  sprintf("%.2f - %.2f", q[1], q[2])
}

biome_summary <- state_summary |>
  dplyr::group_by(biome) |>
  dplyr::summarise(
    n_states                = dplyr::n(),
    median_temp_c_mean       = round(mean(median_temp_c, na.rm = TRUE), 2),
    peak_rr_median           = round(stats::median(peak_rr, na.rm = TRUE), 2),
    peak_rr_iqr              = iqr_str(peak_rr),
    temp_at_peak_c_median    = round(stats::median(temp_at_peak_c, na.rm = TRUE), 2),
    temp_at_peak_c_iqr        = iqr_str(temp_at_peak_c),
    pct_ci_excludes_1        = round(100 * mean(ci_excludes_1, na.rm = TRUE), 1),
    pct_has_autocorr         = round(100 * mean(has_autocorr, na.rm = TRUE), 1),
    pct_peak_is_cold_driven  = round(100 * mean(peak_direction == "cold", na.rm = TRUE), 1),
    .groups = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(median_temp_c_mean))

write.csv(biome_summary, "tables/table_biome_summary.csv", row.names = FALSE)

cat("\n--- Biome summary (Table X) ---\n")
print(biome_summary)

# ------------------------------------------------------------------------
# Step 3 -- Spearman correlation, state level (n=27), bootstrap CI
# ------------------------------------------------------------------------

cortest <- stats::cor.test(state_summary$median_temp_c, state_summary$peak_rr, method = "spearman")
rho_point <- unname(cortest$estimate)
rho_p <- cortest$p.value

spearman_stat <- function(data, indices) {
  d <- data[indices, ]
  stats::cor(d$median_temp_c, d$peak_rr, method = "spearman")
}

set.seed(20260713)
boot_out <- boot::boot(
  data = state_summary |> dplyr::select(median_temp_c, peak_rr),
  statistic = spearman_stat,
  R = 10000
)
boot_ci <- boot::boot.ci(boot_out, type = "perc")
rho_ci_lo <- boot_ci$percent[4]
rho_ci_hi <- boot_ci$percent[5]

cat(sprintf(
  "\n--- Spearman correlation (state-level, n=%d) ---\nrho = %.2f, p = %.4f, 95%% bootstrap CI [%.2f, %.2f]\n",
  nrow(state_summary), rho_point, rho_p, rho_ci_lo, rho_ci_hi
))

hypothesis_direction <- if (rho_point < 0) {
  "consistent with the acclimatisation hypothesis (hotter states show lower peak RR)"
} else {
  "consistent with the vulnerability hypothesis (hotter states show higher peak RR)"
}
cat("Direction of evidence:", hypothesis_direction, "\n")

correlation_result <- tibble::tibble(
  n = nrow(state_summary),
  rho = round(rho_point, 2),
  p_value = signif(rho_p, 3),
  ci_lo = round(rho_ci_lo, 2),
  ci_hi = round(rho_ci_hi, 2),
  direction = hypothesis_direction
)
write.csv(correlation_result, "tables/table_spearman_correlation.csv", row.names = FALSE)

# ------------------------------------------------------------------------
# Step 4 -- Figures
# ------------------------------------------------------------------------

## Figure A: exposure-response curves by biome ---------------------------

full_curves <- dlnm |>
  dplyr::filter(!is.na(rr)) |>
  dplyr::mutate(has_autocorr_f = factor(has_autocorr, levels = c(FALSE, TRUE)))

biome_clip_range <- full_curves |>
  dplyr::group_by(biome) |>
  dplyr::summarise(
    q_lo = stats::quantile(exposure, 0.025, na.rm = TRUE),
    q_hi = stats::quantile(exposure, 0.975, na.rm = TRUE),
    .groups = "drop"
  )

curves_clipped <- full_curves |>
  dplyr::left_join(biome_clip_range, by = "biome") |>
  dplyr::filter(exposure >= q_lo, exposure <= q_hi)

# Fixed-effect (inverse-variance) pooling of per-state log-RR curves onto a
# common per-biome temperature grid, to draw one median curve + 95% CI band
# per biome without pretending per-state curves share a single model.
pool_biome_curve <- function(biome_name, n_grid = 60) {
  rng <- biome_clip_range |> dplyr::filter(biome == biome_name)
  grid <- seq(rng$q_lo, rng$q_hi, length.out = n_grid)

  states_here <- full_curves |> dplyr::filter(biome == biome_name) |> dplyr::pull(uf) |> unique()

  per_state <- purrr::map_dfr(states_here, function(u) {
    sdf <- full_curves |> dplyr::filter(uf == u) |> dplyr::arrange(exposure)
    if (nrow(sdf) < 2) return(NULL)
    log_rr <- log(sdf$rr)
    log_lo <- log(sdf$lo)
    log_hi <- log(sdf$hi)
    se <- (log_hi - log_lo) / (2 * 1.96)

    in_range <- grid >= min(sdf$exposure) & grid <= max(sdf$exposure)
    interp_rr <- rep(NA_real_, length(grid))
    interp_se <- rep(NA_real_, length(grid))
    interp_rr[in_range] <- stats::approx(sdf$exposure, log_rr, xout = grid[in_range])$y
    interp_se[in_range] <- stats::approx(sdf$exposure, se, xout = grid[in_range])$y

    tibble::tibble(uf = u, grid_temp = grid, log_rr = interp_rr, se = interp_se)
  })

  per_state |>
    dplyr::filter(!is.na(log_rr), se > 0) |>
    dplyr::mutate(w = 1 / se^2) |>
    dplyr::group_by(grid_temp) |>
    dplyr::summarise(
      n_states_pt = dplyr::n(),
      pooled_log_rr = sum(w * log_rr) / sum(w),
      pooled_se = sqrt(1 / sum(w)),
      .groups = "drop"
    ) |>
    dplyr::filter(n_states_pt >= 2) |>
    dplyr::transmute(
      biome = biome_name,
      grid_temp,
      rr_pool = exp(pooled_log_rr),
      lo_pool = exp(pooled_log_rr - 1.96 * pooled_se),
      hi_pool = exp(pooled_log_rr + 1.96 * pooled_se)
    )
}

biome_pooled_curves <- purrr::map_dfr(unique(biome_lookup$biome), pool_biome_curve)

state_vlines <- state_summary |> dplyr::select(uf, biome, median_temp_c)

fig_a <- ggplot() +
  geom_ribbon(
    data = biome_pooled_curves,
    aes(x = grid_temp, ymin = lo_pool, ymax = hi_pool, fill = biome),
    alpha = 0.18
  ) +
  geom_line(
    data = curves_clipped,
    aes(x = exposure, y = rr, group = uf, color = biome, linetype = has_autocorr_f),
    linewidth = 0.35, alpha = 0.45
  ) +
  geom_line(
    data = biome_pooled_curves,
    aes(x = grid_temp, y = rr_pool, color = biome),
    linewidth = 1.15
  ) +
  geom_vline(
    data = state_vlines, aes(xintercept = median_temp_c),
    linetype = "dashed", color = "grey45", alpha = 0.35, linewidth = 0.3
  ) +
  geom_hline(yintercept = 1, linetype = "dotted", color = "black", linewidth = 0.4) +
  scale_y_log10() +
  scale_color_manual(values = BIOME_PALETTE, guide = "none") +
  scale_fill_manual(values = BIOME_PALETTE, guide = "none") +
  scale_linetype_manual(values = c(`FALSE` = "solid", `TRUE` = "dashed"), guide = "none") +
  facet_wrap(~biome, scales = "free_x", ncol = 3) +
  labs(
    x = "Temperature (°C)",
    y = "Cumulative relative risk (log scale)",
    title = "Temperature-mortality exposure-response curves by Brazilian biome"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    strip.text = element_text(face = "bold"),
    panel.spacing.x = unit(1.4, "lines"),
    panel.spacing.y = unit(1.2, "lines")
  )

ggsave("figures/fig_biome_exposure_response.png", fig_a, width = 11, height = 7.5, dpi = 300, bg = "white")
ggsave("figures/fig_biome_exposure_response.svg", fig_a, width = 11, height = 7.5, bg = "white")

## Figure B: scatter of median temperature vs peak RR ---------------------

extreme_states <- state_summary |>
  dplyr::filter(peak_rr == max(peak_rr) | peak_rr == min(peak_rr))

annotation_label <- sprintf("Spearman rho = %.2f, p = %.4f", rho_point, rho_p)

fig_b <- ggplot(state_summary, aes(x = median_temp_c, y = peak_rr, color = biome, shape = biome)) +
  geom_point(size = 3.2, alpha = 0.9) +
  ggrepel::geom_text_repel(
    data = extreme_states, aes(label = state_name),
    size = 3.2, color = "black", show.legend = FALSE,
    max.overlaps = Inf, box.padding = 0.6
  ) +
  annotate("text", x = -Inf, y = Inf, label = annotation_label,
           hjust = -0.05, vjust = 1.5, size = 4, fontface = "italic") +
  scale_color_manual(values = BIOME_PALETTE) +
  labs(
    x = "State median temperature (°C)",
    y = "Peak cumulative relative risk",
    color = "Biome", shape = "Biome",
    title = "State-level median temperature vs. peak cumulative relative risk"
  ) +
  theme_minimal(base_size = 12)

ggsave("figures/fig_biome_scatter_rr_temp.png", fig_b, width = 8, height = 6, dpi = 300, bg = "white")
ggsave("figures/fig_biome_scatter_rr_temp.svg", fig_b, width = 8, height = 6, bg = "white")

cat("\nFigures written to figures/, tables written to tables/.\n")
cat("Done.\n")
