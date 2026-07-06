.PHONY: setup link-data data-synth data-real geo web

setup: link-data
	mkdir -p data/bronze data/silver data/public/gold

link-data:
	mkdir -p apps/web/public
	[ -L apps/web/public/data ] || ln -s ../../../data/public apps/web/public/data

data-synth:
	Rscript pipelines/R/00_synth_data.R

data-real:
	Rscript pipelines/R/01_ro_gold.R

geo:
	Rscript pipelines/R/99_export_geo.R

web:
	cd apps/web && npm install && npm run dev
