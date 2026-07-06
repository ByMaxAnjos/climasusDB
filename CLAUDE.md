# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**climasusDB** is the data component of the climaSUS ecosystem: an open platform integrating Brazilian health (DATASUS), climate (INMET, ERA5), and environmental data. All data processing happens via the sibling R package [climasus4r](https://github.com/ByMaxAnjos/climasus4r) (not vendored here — installed separately, e.g. `remotes::install_local('../climasus4r')`). The public-facing atlas is a local-first web app (static Parquet + DuckDB-WASM, no backend server).

This is currently **Phase 0**: a scaffold running entirely on synthetic data for Rondônia (uf=RO), with the real pipeline written but not yet executed.

## Commands

```bash
make setup        # create data/{bronze,silver,public/gold} dirs + symlink apps/web/public/data -> data/public
make data-synth    # generate synthetic Parquet gold dataset offline (<30s), requires climasus4r installed
make data-real     # run the real SIM-DO + INMET pipeline (requires network; slow/not run in Phase 0)
make geo           # export real RO municipality polygons via geobr (requires network); a placeholder geojson already exists
make web           # npm install + vite dev server for the atlas at http://localhost:5173
```

Frontend-only commands (from `apps/web/`):
```bash
npm run dev        # vite dev server
npm run build       # tsc -b && vite build
npm run preview     # preview production build
```

There is no test suite yet.

## Architecture

```
pipelines/R/  →  data/bronze  →  data/silver  →  data/public/gold  →  apps/web (atlas)
 (climasus4r)      (raw)          (standardized)   (Parquet served       (React + MapLibre
                                                      via HTTP Range)      + DuckDB-WASM)
```

- **`data/public/`** is the exact layout that becomes the public GCS bucket in the cloud phase — no application code changes on migration, only the base URL (`VITE_DATA_URL` env var, not yet wired up).
- **`pipelines/R/00_synth_data.R`** — Phase 0 scaffold: generates synthetic `health_climate_daily` gold data offline using only the `municipio_meta.parquet` dimension embedded in climasus4r (no DATASUS/INMET download). Writes `v0.1.0` and a minimal `data/public/catalog.json`.
- **`pipelines/R/01_ro_gold.R`** — Phase 1 real pipeline (NOT run as part of Phase 0 scaffold; requires network access to DATASUS via `microdatasus` and INMET). Chains the climasus4r pipeline (`sus_data_import` → `sus_data_clean_encoding` → `sus_data_standardize` → `sus_data_filter_cid` → `sus_data_aggregate` → `sus_climate_aggregate`) and writes `v1.0.0` to the same schema, so the frontend requires zero changes when switching from synthetic to real data. Only difference is bumping `catalog.json`'s `latest` pointer from `v0.1.0` to `v1.0.0`.
- **`pipelines/R/99_export_geo.R`** — one-off export of real RO municipality polygons via `geobr`, committed to `apps/web/public/geo/municipios_ro.geojson`. Requires network; a placeholder geojson (squares centered on municipality centroids) already exists so the atlas can be tested without it.

### Data contract

The single dataset consumed by the atlas is `health_climate_daily`, grain **município × dia**, documented in `docs/DATA_MODEL.md` and `catalog/health_climate_daily.datapackage.json` (Frictionless Data Package format). Path convention:

```
data/public/gold/health_climate_daily/v{SEMVER}/uf=RO/data.parquet
```

Key rules (see `docs/DATA_MODEL.md` for the full column contract):
- The schema is identical between synthetic (v0.1.0) and real (v1.0.0) data — the frontend never needs to change between phases.
- Always write with `climasus4r::write_parquet_climasus()`, which embeds the `sus_meta` provenance attribute as JSON under the `"climasus_meta"` Arrow schema key. Never use `sus_as_arrow()`/`sus_as_duckdb()` for public dataset persistence — they use a different, incompatible metadata key (`"sus_meta"`).
- Mark synthetic vs. real data via `sus_meta(x, user = list(synthetic = TRUE|FALSE, generator = "<script>"))`.
- Zstd compression, `chunk_size = 1e5` (small row groups for efficient partial reads via DuckDB-WASM HTTP range requests), rows sorted by `code_muni, date` before writing.
- Canonical keys: `code_muni` (IBGE 7-digit code), `station_code` (INMET station), `date`.

### Frontend (`apps/web/`)

React 19 + TypeScript + Vite. No backend — all queries run client-side against a Parquet file served over HTTP range requests.

- **`src/db.ts`** — lazy-singleton DuckDB-WASM instance; registers the gold Parquet file as a virtual table (`HEALTH_CLIMATE_FILE`) on first query, then all data access goes through the `query<T>(sql)` helper which runs SQL directly against the remote Parquet via HTTP range requests (no data downloaded upfront).
- **`src/types.ts`** mirrors the `docs/DATA_MODEL.md` schema contract (`HealthClimateRow`) — keep these in sync if the gold schema changes.
- **`src/App.tsx`** — top-level state/orchestration: loads the municipality list once, re-aggregates the map metric via a `GROUP BY code_muni` query on metric/status change, and fetches a per-municipality time series on selection change. All data flows through `db.ts`'s `query()`.
- **`src/Map.tsx`** — MapLibre choropleth keyed by `code_muni`, reading `apps/web/public/geo/municipios_ro.geojson`.
- **`src/TimeSeries.tsx`** — Observable Plot time series for the selected município.
- DuckDB-WASM bundles are currently loaded from jsdelivr (not vendored locally) — see the `ponytail:` comment in `vite.config.ts` for the intentional tradeoff and when to revisit it.
- `apps/web/public/data` is a symlink to `../../../data/public`, created by `make setup` — do not commit it as a real directory.

## Agent Ecosystem (from sibling climasus4r project)

This repo shares the `agents/` specialist-agent ecosystem documented in the sibling `climasus4r` project's CLAUDE.md (21 specialist agents for structural/data/functional review, routed via `agents/agent-governance.instructions.md`). If `agents/` is present in this repo or a linked path, follow that routing: start with the most specific agent; use `TechnicalCoordinator` for broad/ambiguous asks, `ProjectAnalyst` to understand project structure.
