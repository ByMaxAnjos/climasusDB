.PHONY: setup link-data data-synth data-real geo web publish national stac check-small-cells

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

geo:
	Rscript pipelines/R/99_export_geo.R

web:
	cd apps/web && npm install && npm run dev

national:
	Rscript pipelines/R/run_national.R

stac:
	Rscript pipelines/R/build_stac.R

check-small-cells:
	Rscript pipelines/R/check_small_cells.R

# Fase 5 — requer projeto GCP configurado (infra/setup_gcp.sh) e DATA_BUCKET definido.
publish:
	gsutil -m rsync -r -d data/public/ gs://$(DATA_BUCKET)/
