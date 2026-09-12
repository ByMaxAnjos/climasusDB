.PHONY: setup link-data data-synth data-real data-real-manifest geo-br tiles-br web publish publish-r2 r2-cors national gridded dlnm muni-summary stac check check-small-cells dashboard

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

# Painel interno de controle (schema, cobertura, imputação, células pequenas,
# inventário do catálogo, registro de terceiros). Gerado sob demanda, não faz
# parte do deploy público (docs/dashboard/ é gitignored). Lê data/public/,
# não baixa nem reprocessa nada.
dashboard:
	Rscript -e 'rmarkdown::render("pipelines/R/dashboard.Rmd", output_file = "index.html", output_dir = "docs/dashboard", knit_root_dir = getwd())'

# Fase 5 — requer projeto GCP configurado (infra/setup_gcp.sh) e DATA_BUCKET definido.
# Guard obrigatório: rsync -d é destrutivo — DATA_BUCKET vazio apagaria o bucket errado.
publish:
	@test -n "$(DATA_BUCKET)" || { echo "ERRO: defina DATA_BUCKET (make publish DATA_BUCKET=meu-bucket)"; exit 1; }
	gsutil -m rsync -r -d data/public/ gs://$(DATA_BUCKET)/

# Cloudflare R2 (S3-compatible). Requer credenciais de uma API Token R2
# (dashboard → R2 → Manage API Tokens) configuradas em `aws configure
# --profile r2`, e R2_ACCOUNT_ID / R2_BUCKET definidos.
# Uso: make publish-r2 R2_ACCOUNT_ID=xxxx R2_BUCKET=climasusdb-gold
publish-r2:
	@test -n "$(R2_ACCOUNT_ID)" || { echo "ERRO: defina R2_ACCOUNT_ID"; exit 1; }
	@test -n "$(R2_BUCKET)" || { echo "ERRO: defina R2_BUCKET"; exit 1; }
	aws s3 sync data/public/ s3://$(R2_BUCKET)/ \
		--profile r2 \
		--endpoint-url https://$(R2_ACCOUNT_ID).r2.cloudflarestorage.com \
		--delete
	# Segunda passada só pra *.json (catalog.json, datapackage.json, STAC):
	# são "ponteiros" que catalog.R regenera a cada publicação — sem
	# Cache-Control explícito, o R2 não envia nenhum e navegadores aplicam
	# cache heurístico, servindo metadados desatualizados por horas. `cp
	# --recursive` (não `sync`) força reenviar o header mesmo quando o
	# conteúdo não mudou.
	aws s3 cp data/public/ s3://$(R2_BUCKET)/ \
		--profile r2 \
		--endpoint-url https://$(R2_ACCOUNT_ID).r2.cloudflarestorage.com \
		--recursive --exclude "*" --include "*.json" \
		--cache-control "no-cache" \
		--content-type "application/json" \
		--metadata-directive REPLACE

# Aplica a política de CORS (pipelines/config/r2-cors.json) ao bucket R2 —
# necessária pra o navegador (front num host, dados noutro) poder ler os
# Parquet via HTTP range request. Rodar uma vez (ou após editar o JSON).
r2-cors:
	@test -n "$(R2_ACCOUNT_ID)" || { echo "ERRO: defina R2_ACCOUNT_ID"; exit 1; }
	@test -n "$(R2_BUCKET)" || { echo "ERRO: defina R2_BUCKET"; exit 1; }
	aws s3api put-bucket-cors --bucket $(R2_BUCKET) \
		--profile r2 \
		--endpoint-url https://$(R2_ACCOUNT_ID).r2.cloudflarestorage.com \
		--cors-configuration file://pipelines/config/r2-cors.json
