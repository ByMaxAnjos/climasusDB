# Fase 5 — imagem do Cloud Run Job que roda o pipeline R (mesmo `make data-real`
# usado localmente). rocker/geospatial já traz sf/gdal/geos; climasus4r e as
# demais deps vêm do renv.lock, garantindo a mesma pin de versões do dev local.
FROM rocker/geospatial:4.5.1

WORKDIR /app

RUN R -e "install.packages('renv', repos = 'https://cran.r-project.org')"

COPY renv.lock DESCRIPTION ./
COPY renv/activate.R renv/settings.json renv/
RUN R -e "renv::restore()"

COPY pipelines/ pipelines/

# `gcloud storage rsync` roda fora do container (ver infra/deploy_cloud_run_job.sh);
# este container só produz data/public localmente dentro do job.
CMD ["Rscript", "-e", "targets::tar_make(script = 'pipelines/_targets.R')"]
