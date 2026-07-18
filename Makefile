.PHONY: setup link-data data-synth data-real data-real-manifest geo-br tiles-br web publish national gridded dlnm muni-summary stac check check-small-cells

setup: link-data
	mkdir -p data/bronze data/silver data/public/gold

link-data:
	mkdir -p apps/web/public
	[ -L apps/web/public/data ] || ln -s ../../../data/public apps/web/public/data

data-synth:
	Rscript pipelines/R/00_synth_data.R

data-real:
	Rscript -e 'targets::tar_make(script = "pipelines/_targets.R")'

data-real-manifest:
	Rscript -e 'targets::tar_manifest(script = "pipelines/_targets.R")'

geo-br:
	Rscript pipelines/R/99_export_geo_br.R

# Gera apps/web/public/tiles/municipios_br.pmtiles (requer tippecanoe:
# `brew install tippecanoe`). Substitui a malha de municípios usada pelo
# MapLibre em Map.tsx — geo-br continua necessário para popular os
# seletores de Região/Estado/Município e para o contorno de estados.
tiles-br:
	Rscript pipelines/R/generate_pmtiles.R

web:
	cd apps/web && npm install && npm run dev

national:
	Rscript pipelines/R/run_national.R

# Fase 3, trilha A — datasets Gold complementares em grade (ERA5, CHIRPS,
# PRODES, poluição CAMS), agregados por município. Independente de
# `make national`. Uso: make gridded  ou  Rscript pipelines/R/run_gridded.R RO,SP
gridded:
	Rscript pipelines/R/run_gridded.R

# Indicador de risco relativo (DLNM), 1 modelo por UF. Requer `make national`
# já ter rodado para as UFs desejadas (lê data/silver/, não baixa nada de
# novo). Uso: make dlnm  ou  Rscript pipelines/R/run_dlnm.R RO,SP
dlnm:
	Rscript pipelines/R/run_dlnm.R

# Resumo por município (usado pelas páginas do atlas). Requer `make national`.
muni-summary:
	Rscript pipelines/R/run_muni_summary.R

stac:
	Rscript pipelines/R/build_stac.R

# Valida todas as partições de health_climate_daily contra docs/DATA_MODEL.md.
check:
	Rscript pipelines/R/check_schema.R

check-small-cells:
	Rscript pipelines/R/check_small_cells.R

# Fase 5 — requer projeto GCP configurado (infra/setup_gcp.sh) e DATA_BUCKET definido.
# Guard obrigatório: rsync -d é destrutivo — DATA_BUCKET vazio apagaria o bucket errado.
publish:
	@test -n "$(DATA_BUCKET)" || { echo "ERRO: defina DATA_BUCKET (make publish DATA_BUCKET=meu-bucket)"; exit 1; }
	gsutil -m rsync -r -d data/public/ gs://$(DATA_BUCKET)/
