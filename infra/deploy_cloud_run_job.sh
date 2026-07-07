#!/usr/bin/env bash
# Fase 5 — builda a imagem (infra/Dockerfile), publica no Artifact Registry,
# cria o Cloud Run Job e um Cloud Scheduler mensal que o executa — mesma
# lógica de `make data-real`, agora recorrente e na nuvem.
#
# NAO EXECUTAVEL sem projeto GCP (ver infra/setup_gcp.sh primeiro).
#
# Uso: PROJECT_ID=... ./infra/deploy_cloud_run_job.sh

set -euo pipefail

: "${PROJECT_ID:?defina PROJECT_ID}"
REGION="${REGION:-southamerica-east1}"
REPO="${REPO:-climasusdb}"
JOB_NAME="${JOB_NAME:-climasusdb-pipeline}"
SA_EMAIL="${SA_NAME:-climasusdb-pipeline}@${PROJECT_ID}.iam.gserviceaccount.com"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/pipeline:latest"

gcloud artifacts repositories create "$REPO" \
  --repository-format=docker --location "$REGION" --project "$PROJECT_ID" || true

gcloud builds submit --tag "$IMAGE" -f infra/Dockerfile . --project "$PROJECT_ID"

gcloud run jobs deploy "$JOB_NAME" \
  --image "$IMAGE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --service-account "$SA_EMAIL" \
  --memory 4Gi --cpu 2 --task-timeout 3600 --max-retries 1

# Agenda execução mensal (dia 1, 03:00 America/Sao_Paulo)
gcloud scheduler jobs create http "${JOB_NAME}-monthly" \
  --project "$PROJECT_ID" --location "$REGION" \
  --schedule "0 3 1 * *" --time-zone "America/Sao_Paulo" \
  --uri "https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${JOB_NAME}:run" \
  --http-method POST \
  --oauth-service-account-email "$SA_EMAIL" || true

echo "== Job '${JOB_NAME}' publicado. Rodar manualmente: gcloud run jobs execute ${JOB_NAME} --region ${REGION} =="
echo "== Após rodar, sincronizar dados: gsutil -m rsync -r -d data/public/ gs://\${DATA_BUCKET}/ =="
