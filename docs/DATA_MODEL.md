# Contrato de schema — `health_climate_daily` (mart do atlas, Fase 0/1)

Grão: **município × dia**. Este é o único dataset consumido pelo scaffold da Fase 0
(sintético) e pela Fase 1 (real) — o schema é idêntico nas duas para que o frontend
não mude entre elas.

Caminho: `data/public/gold/health_climate_daily/v{SEMVER}/uf=RO/data.parquet`
(v0.1.0 = sintético; v1.0.0 = real).

| Coluna | Tipo (Arrow/Parquet) | Tipo (TS) | Descrição |
|---|---|---|---|
| `code_muni` | int32 | `number` | Código IBGE do município, 7 dígitos (chave) |
| `name_muni` | utf8 | `string` | Nome do município |
| `date` | date32 | `string` (ISO `YYYY-MM-DD`) | Dia (chave) |
| `deaths_total` | int32 | `number` | Óbitos totais nos grupos CID climate-sensitive |
| `deaths_resp` | int32 | `number` | Óbitos do grupo respiratório |
| `deaths_circ` | int32 | `number` | Óbitos do grupo circulatório |
| `tmean` | float64 | `number` | Temperatura média diária (°C) |
| `tmax` | float64 | `number` | Temperatura máxima diária (°C) |
| `tmin` | float64 | `number` | Temperatura mínima diária (°C) |
| `precip` | float64 | `number` | Precipitação diária (mm) |
| `rh` | float64 | `number` | Umidade relativa média (%) |

Colunas adicionais na Fase 1 (real; aditivas, não quebram o schema acima):
`is_heatwave` (bool), `station_code` (utf8), `distance_km` (float32).

## Proveniência

Todo Parquet é gravado com `climasus4r::write_parquet_climasus()`, que embute o
atributo `sus_meta` como JSON no schema Arrow, chave `"climasus_meta"`. Campo extra
usado pela plataforma: `sus_meta(x, user = list(synthetic = TRUE|FALSE, generator = "<script>"))`.

Regra: **nunca** usar `sus_as_arrow()`/`sus_as_duckdb()` para persistência de dataset
público — usam uma chave de metadados diferente (`"sus_meta"`), incompatível com
`from_arrow_climasus()` e com o leitor de catálogo da plataforma.

## Convenções físicas do Parquet

- Compressão Zstd.
- `chunk_size = 1e5` (row groups pequenos — leitura parcial eficiente via DuckDB-WASM/HTTP range).
- Linhas ordenadas por `arrange(code_muni, date)` antes de gravar.
- CRS das geometrias (quando houver, ex. `dim_municipality`): EPSG:4326.

## Chaves canônicas do pipeline (climasus4r)

- `code_muni` — IBGE 7 dígitos.
- `station_code` — estação INMET.
- `date` — dia.
