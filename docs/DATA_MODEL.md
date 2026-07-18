# Contrato de schema — `health_climate_daily` (mart do atlas)

Grão: **município × dia**. O schema é idêntico entre o dado sintético do CI
(`00_synth_data.R`) e o real (pipeline nacional), para que o frontend nunca
precise mudar.

Caminho: `data/public/gold/health_climate_daily/v{SEMVER}/uf={UF}/data.parquet`
— particionado por UF (v1.0.0 = real, 27 UFs). O CI gera uma partição
sintética `v0.1.0/uf=RO` só para o smoke test.

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

**Correção (achada em revisão por pares):** este documento previa `is_heatwave`
(bool), `station_code` (utf8), `distance_km` (float32) como colunas adicionais
aditivas da Fase 1. Conferido contra o Parquet publicado (`v1.0.0`, todas as
27 UFs): **essas três colunas não existem no arquivo real.** Causa raiz:
`climasus4r::sus_climate_aggregate(temporal_strategy="exact")` — usada por
`make_health_climate_mart()` — descarta explicitamente qualquer coluna que
não seja `date`/`code_muni`/uma das `climate_var` pedidas antes do join
(`.join_exact()`, `dplyr::select("date","code_muni", dplyr::all_of(target_vars))`
em `climasus4r`), então `station_code`/`distance_km` nunca sobrevivem ao
join mesmo que estivessem no `climate_data` de entrada. Duas saídas: (a)
adicionar essas colunas de fato, o que exige mudar `climasus4r` para
preservar colunas extra no join "exact" (mudança na dependência, fora do
escopo desta correção), ou (b) manter o schema documentado igual ao real (o
que este documento faz agora). `is_heatwave` seria redundante de qualquer
forma com o dataset dedicado `heatwave_events`, abaixo.

**Nenhuma supressão de célula pequena é aplicada neste dataset** (grão
município-dia) — ver a seção `health_climate_muni_summary` abaixo para a
política de supressão adotada e a justificativa de por que ela não se aplica
ao grão diário.

**Cobertura: 5.569 dos 5.570 municípios do IBGE — município ausente
identificado (achado em revisão por pares).** Comparando `code_muni` presente
em `health_climate_daily` contra `municipio_meta.parquet` (embutido no
`climasus4r`, fonte de verdade IBGE), o único município ausente é **Luciara,
MT (código IBGE 5105309, população ~2.036)** — não Fernando de Noronha, como
uma versão anterior deste documento especulava sem checar. Causa raiz
confirmada: o Silver de SIM-DO para MT tem 22 registros de óbito com
`codigo_municipio_residencia` = Luciara, mas **zero** com
`codigo_municipio_ocorrencia` = Luciara. `resolve_geo_col_name()`
(`pipelines/R/gold.R`) prioriza ocorrência sobre residência para SIM,
propositalmente (é a convenção epidemiológica padrão para mortalidade no
Brasil) — então os 22 óbitos de residentes de Luciara, todos ocorridos em
outro município (provavelmente por transferência hospitalar, já que uma
cidade de ~2 mil habitantes tipicamente não tem estabelecimento de saúde
para óbitos complexos), são contabilizados no município de ocorrência, não
em Luciara. Luciara simplesmente nunca teve um óbito climate-sensitive
*ocorrido* dentro de seus limites no período 2018–2023. **Isto não é um bug
de processamento** — é uma consequência esperada, ainda que não-óbvia, da
convenção ocorrência-sobre-residência: qualquer município pequeno sem
estabelecimento de saúde próprio pode, em princípio, ficar ausente do mart
pelo mesmo motivo. Nenhum outro município no Brasil teve essa sorte (ou
azar) de zerar completamente no período — Luciara é o único caso, mas o
mecanismo generaliza e vale documentar para usuários de municípios pequenos
que notarem contagens muito baixas ou ausência total.

**Pareamento centroide-estação: efeito quantificado (achado em revisão por
pares).** O município é pareado à estação INMET mais próxima pelo centróide
populacional (não pelo polígono real, que o `climasus4r` não embute — ver
`muni_points_ro()`/`build_health_sf()` em `pipelines/R/gold.R`). Comparação
real contra polígonos IBGE (via `geobr::read_municipality()`) para dois
estados contrastantes:

| UF | Municípios | Estações | % pareado a estação diferente (centroide vs. polígono) | Distância mediana centroide→estação | Distância mediana polígono→estação | Diferença mediana | Diferença máxima | Área mediana do município |
|---|---|---|---|---|---|---|---|---|
| AM | 62 | 26 | 24,2% | 100,0 km | 15,8 km | 76,4 km | 209,0 km | 13.296 km² |
| SP | 645 | 42 | 4,8% | 32,0 km | 19,9 km | 10,3 km | 40,4 km | 281 km² |

Em estados com municípios muito grandes e esparsos (Amazonas: mediana de
13.296 km², máximo de 123.011 km² — maior que muitos países), quase 1 em
cada 4 municípios seria pareado à estação errada pelo critério de centroide,
com erro de distância mediano de 76 km. Em estados de municípios pequenos e
densos (São Paulo), o efeito é bem menor (4,8% pareados diferente, erro
mediano de 10 km), mas não nulo. **Implicação prática:** a variável climática
diária de `health_climate_daily` para municípios amazônicos extensos deve
ser tratada como uma aproximação regional, não como a leitura da estação
fisicamente mais próxima do local real do óbito — um usuário fazendo
análise fina em estados do Norte deveria considerar `sus_grid_era5()`
(cobertura gridded, sem esse viés de centroide) como alternativa, já
mencionada no Methods do manuscrito como a via usada no Case Study 3.
Script de referência: `pipelines/R/scratch/centroid_vs_polygon.R` (ad-hoc,
não parte do pipeline de produção).

## `health_climate_distributed_lag` (insumo de modelagem, Fase 2b)

Grão: **município × dia**, mesma cobertura de `health_climate_daily`, mas com
`temporal_strategy="distributed_lag"` em vez de `"exact"` — cada linha carrega
o histórico de exposição climática dos últimos N dias (matriz de lag), não só
o valor do dia. Existe **especificamente para alimentar modelagem** (DLNM ou
outra) que precise de exposição defasada; não é consumido pelo atlas.

Caminho: `data/public/gold/health_climate_distributed_lag/v{SEMVER}/uf={UF}/data.parquet`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `code_muni`, `name_muni`, `date` | como acima | chaves |
| `deaths_total`, `deaths_resp`, `deaths_circ` | int/double | como acima |
| `{climate_var}_lag0` ... `{climate_var}_lag{L}` | float64 | valor de `climate_var` (config `dlnm.climate_var`, default `tair_dry_bulb_c`) há `N` dias, `N` de 0 a `dlnm.lag_days` (default 21) |
| `{climate_var}` | float64 | valor do dia corrente (duplicado do `_lag0`, mantido pela função de origem) |

Gerado por `pipelines/R/dlnm.R::make_distributed_lag_mart()`. **Não** confundir
com `health_climate_daily`: os dois convivem, grãos e propósitos diferentes.

## `dlnm_exposure_response` / `dlnm_lag_response` / `dlnm_surface` (saída de modelagem, Fase 2b)

Um DLNM (`climasus4r::sus_mod_dlnm()`) é ajustado **por UF** (não por
município — ver comentário em `pipelines/R/dlnm.R` sobre estabilidade
estatística), a partir de `health_climate_distributed_lag`. Três datasets,
consumidos pelos 3 gráficos do indicador "Relative risk (DLNM)" em
`Explore.tsx` (espelham os 3 tipos de `climasus4r::sus_mod_plot_dlnm()`:
`overall`, `lag`, `surface`):

- **`dlnm_exposure_response`** — grão UF × ponto de grade de exposição
  (~100 pontos/UF, do 1º ao 99º percentil de temperatura observada). Curva
  de risco relativo cumulativo (todos os lags somados) em função da
  temperatura, centrada na mediana (RR=1) — mesma curva suave que
  `climasus4r:::.plot_dlnm_overall()` desenha em R.

  | Coluna | Tipo | Descrição |
  |---|---|---|
  | `uf` | utf8 | Unidade federativa (chave) |
  | `disp_ratio` | float64 | Razão de dispersão do GLM (ver achado abaixo) |
  | `has_autocorr` | bool | `TRUE` = autocorrelação residual significativa (Ljung-Box) — ver achado abaixo |
  | `exposure` | float64 | Temperatura (°C) do ponto de grade |
  | `rr` | float64 | Risco relativo cumulativo vs. mediana, nesse ponto |
  | `lo`, `hi` | float64 | Intervalo de confiança 95% |
  | `pct` | float64 ou `NULL` | Não-nulo só nos ~6 pontos de grade mais próximos dos percentis 25/50/75/90/95/99 (marcadores do gráfico) |

- **`dlnm_lag_response`** — grão UF × lag (dia, 0 a `dlnm.lag_days`). Efeito
  isolado por dia de defasagem, na temperatura do percentil 75.

  | Coluna | Tipo | Descrição |
  |---|---|---|
  | `uf`, `disp_ratio`, `has_autocorr` | como acima | |
  | `lag` | int | Dia de defasagem |
  | `rr`, `lo`, `hi` | float64 | Risco relativo (e IC 95%) daquele lag isolado |
  | `rr_cum` | float64 | Risco relativo acumulado até aquele lag |

- **`dlnm_surface`** — grão UF × exposição × lag (~100 × 22 pontos/UF).
  Superfície bidimensional completa (sem IC — é só o ponto estimado), pro
  heatmap "onde na grade temperatura × tempo o efeito é mais forte".

  | Coluna | Tipo | Descrição |
  |---|---|---|
  | `uf`, `disp_ratio`, `has_autocorr` | como acima | |
  | `exposure` | float64 | Temperatura (°C) do ponto de grade |
  | `lag` | int | Dia de defasagem |
  | `rr` | float64 | Risco relativo naquele ponto (exposição, lag) |

Caminho: `data/public/gold/{dlnm_exposure_response,dlnm_lag_response,dlnm_surface}/v{SEMVER}/uf={UF}/data.parquet`.
`disp_ratio`/`has_autocorr` são gravados **como coluna de dado**, duplicando
o que também vai em `climasus_meta.user` (junto com `dlnm_climate_var`,
`dlnm_lag_days`, `dlnm_family`, `dlnm_n_obs`) — o frontend consulta via
DuckDB-WASM, que não lê metadados de schema Arrow linha a linha, então o
aviso de UI (`DlnmOverallChart`/`DlnmLagChart`/`DlnmSurfaceChart`) precisa do
valor como coluna pra funcionar.

**Limitação conhecida, por desenho:** um único RR por UF mistura municípios
com climas e populações muito diferentes dentro do mesmo estado (ex.: BA vai
do semiárido ao litoral). É um agregado estadual, não uma estimativa local —
tratar como indicador de triagem regional, não como risco município-específico.

**Achado real da rodada nacional (v1.0.0, `dof_per_year=4` default):** 22 das
27 UFs têm autocorrelação residual significativa (teste de Ljung-Box,
`dlnm_has_autocorr=TRUE`) — só AC, AP, RO, RR e TO (as UFs com menos
óbitos/dia) passam limpas. Testado empiricamente: aumentar `dof_per_year`
(4→6→8→10) reduz a superdispersão (SP: 1,98→1,58) mas **não** elimina a
autocorrelação em nenhum nível testado, e desloca o RR estimado (SP p75:
0,964→0,992 conforme o dof) — ou seja, a estimativa é sensível a essa
escolha de tuning, sinal de que agregar uma UF inteira numa única série
diária tem uma estrutura de autocorrelação que spline de tendência sozinho
não resolve. Decisão adotada: publicar mesmo assim com `dof_per_year=4`
(default do pacote) e deixar `dlnm_has_autocorr` no `climasus_meta` como
sinal explícito — **qualquer consumidor (frontend incluso) deve tratar RR de
UFs com `dlnm_has_autocorr=TRUE` como indicativo, não como estimativa
estatisticamente confiável**. Não perseguir um ajuste "perfeito" nessa
granularidade; se isso importar, a evolução correta é mudar a unidade
espacial (capitais/regiões metropolitanas em vez de UF inteira) ou adicionar
controle de dia-da-semana, não só aumentar `dof_per_year`.

## `env_era5_daily` / `env_chirps_daily` / `env_prodes_daily` / `env_pollution_cams_daily` (Fase 3, trilha A)

Datasets Gold complementares, grão **município × dia** (PRODES: município × ano,
com `date` = 1º de janeiro do ano PRODES), gerados por
`pipelines/R/run_gridded.R` (`make gridded`). Cada um vem de uma fonte em
grade (raster/NetCDF) já agregada por município dentro da própria função
`climasus4r::sus_grid_*()` (via `exactextractr`, média ponderada por área) —
o pipeline nunca lida com raster bruto, só recebe tibble pronto.

- `code_muni` (integer, IBGE 7 dígitos) + `date` — chaves, iguais às de `health_climate_daily`.
- `env_era5_daily` / `env_chirps_daily` — variáveis climáticas (temperatura,
  chuva) onde o INMET tem estação esparsa; mesmas unidades físicas de
  `health_climate_daily` (ver `docs/DATA_MODEL.md` acima).
- `env_prodes_daily` — `year`, `deforested_area_km2`, `n_patches`, `biome`.
- `env_pollution_cams_daily` — uma coluna por poluente×métrica (ex. `pm25_mean`).

Não são misturados no mart `health_climate_daily` — nem toda UF/ano tem
cobertura das 4 fontes ao mesmo tempo. Um mart combinado, se necessário, é
responsabilidade de quem consome, via `climasus4r::sus_grid_join()`. Cada um
é descoberto automaticamente pelo catálogo (`pipelines/R/catalog.R`, glob
`gold/*/v*/uf=*/data.parquet`) — nenhuma mudança de catálogo necessária ao
adicionar uma fonte nova.

## `health_climate_muni_summary` (Fase 2c)

Dataset Gold derivado, grão **município** (não município × dia) — uma linha por
município, somando `health_climate_daily` no período coberto pela partição
(2018–2023). Gerado por `pipelines/R/run_muni_summary.R`
(`make_muni_mortality_summary()`, em `pipelines/R/muni_summary.R`), que lê o
mart `health_climate_daily` já publicado e agrega por `code_muni` — não
reprocessa saúde/clima. Se `health_climate_daily` for regenerado (nova versão
ou correção), este dataset precisa ser regerado a partir dele.

| Coluna | Tipo | Descrição |
|---|---|---|
| `code_muni` | integer | IBGE 7 dígitos. |
| `name_muni` | string | Nome do município. |
| `uf` | string | Unidade federativa (partição). |
| `deaths_total` | integer, nullable | Soma de óbitos climate-sensitive (58 grupos CID-10) no período. **`NA` quando suprimido** (ver política de supressão abaixo). |
| `deaths_resp` | integer, nullable | Soma de óbitos respiratórios (subconjunto). **`NA` quando suprimido.** |
| `deaths_circ` | integer, nullable | Soma de óbitos cardiovasculares (subconjunto). **`NA` quando suprimido.** |
| `deaths_total_suppressed` | bool | `TRUE` se `deaths_total` original estava entre 1 e 4 (célula pequena, suprimida). |
| `deaths_resp_suppressed` | bool | `TRUE` se `deaths_resp` original estava entre 1 e 4. |
| `deaths_circ_suppressed` | bool | `TRUE` se `deaths_circ` original estava entre 1 e 4. |
| `n_death_days` | integer | Nº de município-dias com pelo menos 1 óbito registrado em `health_climate_daily` — **não** é contagem de dias de calendário, porque `health_climate_daily` só tem linha para município-dia com óbito (ver acima). Não suprimido (contagem de dias, não de óbitos). |
| `date_start` | date | Primeira data com óbito registrado, dentro da partição. |
| `date_end` | date | Última data com óbito registrado, dentro da partição. |

**Política de supressão de célula pequena (k=5), decidida em revisão por
pares.** Qualquer célula com contagem entre 1 e 4 (inclusive) é substituída
por `NA` e sinalizada em `{coluna}_suppressed=TRUE`; células com 0 ou ≥5 não
são alteradas. Aplicada por coluna (`deaths_total`, `deaths_resp`,
`deaths_circ`) independentemente — um município pode ter `deaths_total`
não-suprimido mas `deaths_circ` suprimido, se o subgrupo for pequeno.
**Achado real da rodada nacional (v1.0.0), antes da supressão:** 5.569
municípios, `sum(deaths_total)` = 4.240.777 — idêntico ao total nacional de
`health_climate_daily`, como esperado de uma agregação que só soma. Após
supressão: 10 municípios com `deaths_total` suprimido, 838 com `deaths_resp`
suprimido, 66 com `deaths_circ` suprimido; a soma nacional de `deaths_total`
não suprimidos cai para 4.240.746 (31 óbitos "escondidos" nas 10 células
suprimidas) — a soma completa (4.240.777) permanece correta e citável como
total do release, só não é recomputável somando a coluna suprimida linha a
linha.

**Por que a mesma supressão NÃO é aplicada a `health_climate_daily` (grão
município-dia):** nesse grão, a contagem diária de óbitos por município é
tipicamente 1-4 por natureza — é assim que uma série de contagem diária de
eventos raros se parece, não uma célula pequena anômala. Suprimir linha a
linha eliminaria a maior parte da série temporal e inviabilizaria o próprio
uso do dataset para modelagem de exposição-resposta (DLNM etc.), que é sua
razão de existir — e é o mesmo padrão de contagem diária que o próprio
TABNET/DATASUS já publica sem supressão. A decisão editorial adotada foi:
suprimir na agregação por período (`health_climate_muni_summary`, onde o
risco de reidentificação é real e a utilidade analítica não depende da
granularidade diária) e não no mart diário — mantendo, porém, o aviso de
risco de disclosure nas Usage Notes do manuscrito para quem re-agregar o
mart diário em cortes finos (ex. por faixa etária, se essa coluna for
adicionada no futuro).
Distribuição fortemente assimétrica: mediana 147 óbitos/município no período,
média 761,5, máximo 273.058 (São Paulo). Dez municípios têm menos de 5 óbitos
totais no período — relevante para a mesma questão de small-cell disclosure
já tratada para `health_climate_daily`.

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
