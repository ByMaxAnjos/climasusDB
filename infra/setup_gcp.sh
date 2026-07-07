#!/usr/bin/env bash
# Fase 5 — provisiona a infraestrutura GCP minima do climasusDB: bucket
# publico de dados (mesmo layout de data/public/), bucket privado do lake
# bruto, e a conta de servico usada pelo Cloud Run Job de atualizacao.
#
# NAO EXECUTAVEL sem um projeto GCP com billing habilitado (Google Cloud for
# Researchers ou equivalente, conforme a proposta do projeto). Rodar apos:
#   gcloud auth login
#   gcloud config set project <PROJECT_ID>
#
# Uso: PROJECT_ID=... REGION=southamerica-east1 ./infra/setup_gcp.sh

set -euo pipefail

: "${PROJECT_ID:?defina PROJECT_ID (ex.: export PROJECT_ID=climasusdb-prod)}"
REGION="${REGION:-southamerica-east1}"
DATA_BUCKET="${DATA_BUCKET:-climasusdb-data}"
LAKE_BUCKET="${LAKE_BUCKET:-climasusdb-lake}"
SA_NAME="${SA_NAME:-climasusdb-pipeline}"

echo "== Habilitando APIs =="
gcloud services enable storage.googleapis.com run.googleapis.com \
  cloudscheduler.googleapis.com --project "$PROJECT_ID"

echo "== Criando bucket publico de dados: gs://$DATA_BUCKET =="
gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://$DATA_BUCKET" || true
gsutil cors set infra/gcs-cors.json "gs://$DATA_BUCKET"
gsutil iam ch allUsers:objectViewer "gs://$DATA_BUCKET"

echo "== Criando bucket privado do lake bruto: gs://$LAKE_BUCKET =="
gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://$LAKE_BUCKET" || true

echo "== Conta de servico para o Cloud Run Job de atualizacao =="
gcloud iam service-accounts create "$SA_NAME" \
  --project "$PROJECT_ID" \
  --display-name "climasusDB pipeline runner" || true

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role "roles/storage.objectAdmin"

echo "== Concluido. Proximo passo: infra/deploy_cloud_run_job.sh =="
