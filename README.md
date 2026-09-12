# climasusDB

Base aberta de dados integrados sobre clima, ambiente e Saúde Única no Brasil.

Componente de dados do ecossistema climaSUS: plataforma aberta que integra dados públicos de saúde (DATASUS), clima (INMET, ERA5) e ambiente do Brasil. Processamento 100% via [climasus4r](https://github.com/ByMaxAnjos/climasus4r); portal público local-first (Parquet estático + DuckDB-WASM, sem backend).

## Como rodar (3 comandos)

```bash
make setup        # cria diretórios de dados + symlink public/data
make data-synth   # gera Parquet sintético de Rondônia (offline, <30s)
make web           # instala deps e sobe o atlas em http://localhost:5173
```

## Arquitetura (visão geral)

```
pipelines/R/  →  data/bronze  →  data/silver  →  data/public/gold  →  apps/web (atlas)
 (climasus4r)      (bruto)        (padronizado)    (Parquet servido       (React + MapLibre
                                                      via HTTP Range)       + DuckDB-WASM)
```

`data/public/` é o layout exato que se torna o bucket GCS público na fase de nuvem — nenhum código muda na migração, só a URL base (`VITE_DATA_URL`).

Ver `docs/DATA_MODEL.md` para o contrato de schema Gold e `docs/PLANO.md` para o roadmap completo.
