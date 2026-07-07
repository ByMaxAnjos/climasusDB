# Hub de computação (Fase 6) — esqueleto, não implantável sem cluster

Documenta a configuração pretendida do JupyterHub/RStudio Server sobre os
dados do climasusDB, conforme `docs/PLANO.md` (Fase 6). **Não executável
nesta sessão**: requer um cluster Kubernetes (GKE) ou VM dedicada, que não
existe ainda — depende da infraestrutura provisionada na Fase 5
(`infra/setup_gcp.sh`).

## Componentes previstos

1. **Zero to JupyterHub** (Helm chart) num cluster GKE, com:
   - Imagem de usuário baseada em `jupyter/r-notebook` + `climasus4r` e
     `climasus4py` pré-instalados (mesmo `renv.lock`/`pyproject.toml` deste
     repositório, para reprodutibilidade idêntica ao pipeline).
   - `singleuser.extraEnv.CLIMASUSDB_DATA_URL` apontando para
     `https://storage.googleapis.com/<DATA_BUCKET>` — os notebooks leem os
     mesmos Parquet públicos que o portal, sem cópia local.
2. **RStudio Server** (alternativa/complemento): mesma imagem base,
   `rocker/rstudio` + climasus4r, exposto via Cloud Run ou VM com proxy.
3. **Autenticação**: OAuth (Google) via `jupyterhub-authenticator` — decisão
   de política de acesso (aberto vs. lista de pesquisadores) ainda pendente,
   fora do escopo técnico deste esqueleto.

## `config.py` mínimo (referência, não aplicado)

```python
# infra/jupyterhub/config.py — referência para `helm install jupyterhub ...`
c.JupyterHub.authenticator_class = "oauthenticator.google.GoogleOAuthenticator"
c.Spawner.environment = {
    "CLIMASUSDB_DATA_URL": "https://storage.googleapis.com/climasusdb-data",
}
c.Spawner.image = "REGION-docker.pkg.dev/PROJECT_ID/climasusdb/notebook:latest"
```

## Quando revisitar

Só faz sentido provisionar isto depois que a Fase 5 (bucket público + Cloud
Run Job) estiver rodando de verdade e houver pesquisadores externos
esperando para usar — ver riscos do roadmap (`docs/PLANO.md`): "exige infra
operada continuamente; nenhum usuário externo existe ainda".
