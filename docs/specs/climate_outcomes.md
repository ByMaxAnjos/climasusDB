# Spec — Desfechos sensíveis ao clima (`climate_outcomes_muni_day`)

> **Mudança de escopo (2026-10-11, pedido do usuário):** grão passou de município × **ano** para município × **dia** × desfecho. Nome anterior `climate_outcomes_muni_year` nunca foi publicado em gold → só renomear (sem nota de depreciação). Alterados: §5–§10.

Dono: Sentinela (epidemiologia). Consumidores: Duto (dados), Vitrine (UI, obrigatória p/ §7), Pena/Lupa (paper). Idioma: pt-BR.

## 1. Estado dos dados (verificado em 2026-10-11)
- `data/silver/sim_do` e `gold/health_climate_daily/v1.0.0`: **somente 2018–2023** (27 UFs). SIH: **não existe** em bronze/silver (só `sim_do`, `inmet_hourly`).
- Excluindo 2020–2021 restam **apenas 4 anos (2018, 2019, 2022, 2023)** → não cumpre "10 anos".
- Denominador: `municipio_meta.parquet` só traz `pop_21` e `pop_25` (pontuais), sem série anual.

## 2. Janela de anos (decisão)
- **Alvo: 2012–2023 menos 2020–2021 = 10 anos** (2012–2019, 2022, 2023). Coluna `covid_period` não existe: 2020–2021 são simplesmente omitidos (e documentados no paper).
- Requer baixar SIM 2012–2017 (**precisa de aprovação do usuário**, rede/lento). Fallback sem download: 4 anos (2018, 2019, 2022, 2023), declarado como limitação.
- Duto: ler `year_min/year_max/exclude_years` de config (`2012`, `2023`, `c(2020,2021)`), não hardcode.

## 3. Sistemas
- **SIM-DO (obrigatório, v1)**: óbitos por **causa básica**, município de **residência** (`codigo_municipio_residencia`, 7 díg. → converter para IBGE 7; checar 6 vs 7 dígitos). Atenção: o mart diário atual usa *ocorrência*; este indicador usa **residência** (casa com o denominador). Documentar a diferença.
- **SIH (v2, opcional)**: internações aprovadas (AIH) por diagnóstico principal, residência. Só após Duto ingerir; coluna `system` já prevista no schema.

## 4. Desfechos (grupos de `climasus4r:::.icd_disease_groups`, `climate_sensitive = TRUE`)
Núcleo v1 (12 grupos; usar `disease_group` em `sus_data_filter_cid()`; nomes exatos do pacote):

| `outcome` | CID-10 | Mecanismo climático |
|---|---|---|
| `cardiovascular` | I00-I99 | calor/frio extremo |
| `respiratory_syndrome` | J00-J22, J40-J46 | frio, poluição, umidade |
| `heat_related` | E86, T67, X30 | calor |
| `cold_exposure` | X31 | frio |
| `diarrheal` | A00-A09 | chuva, saneamento, calor |
| `dengue` | A90, A91 | T, chuva |
| `vector_borne` | A75-A79, A90-A99 | T, chuva (inclui dengue; não somar com dengue) |
| `malaria` | B50-B54 | T, chuva |
| `leptospirosis` | A27 | enchentes |
| `diabetes` | E10-E14 | calor |
| `mental_disorders` | F00-F99 | calor |
| `suicide_self_harm` | X60-X84, Y87.0 | calor |

- Adicionais opcionais (v1.1): `drowning` (W65-W74), `natural_disasters` (X36-X39), `tuberculosis`, `chagas`, `leishmaniasis`.
- Agregado `climate_sensitive_all` fica **fora** do núcleo (sobrepõe grupos); expor só como linha extra `outcome="climate_sensitive_all"` se Duto quiser total — nunca somar linhas entre `outcome`s (grupos se sobrepõem: dengue ⊂ vector_borne; cardiovascular ∩ air_pollution_related).
- Excluir `ill_defined` do núcleo (usar só como controle de qualidade, §9).
- Dupla verificação: Duto lista `list_disease_groups(climate_sensitive_only=TRUE)` e compara com esta tabela; divergência → avisar Sentinela.

## 5. Schema `climate_outcomes_muni_day` (grão: município × dia × desfecho)
Path: `data/public/gold/climate_outcomes_muni_day/v1.0.0/uf={UF}/data.parquet` (zstd, chunk 1e5, ordenado por `code_muni, date, outcome`; `write_parquet_climasus()`; `sus_meta(user=list(synthetic=FALSE, ...))`).

| coluna | tipo | descrição |
|---|---|---|
| `code_muni` | int32 | IBGE 7 dígitos (**residência**) |
| `date` | date32 | data do óbito (`DTOBITO`) |
| `system` | string | `SIM` (v1) \| `SIH` (v2) |
| `outcome` | string | slug do §4 |
| `n_events` | int32 | contagem bruta (≥1), **sem supressão** (§7) |

- **Esparso**: linha só quando `n_events > 0` (5.570 × ~3.650 dias × 12 desfechos ≈ 244 M linhas denso — inviável; mesmo padrão de `health_climate_daily`). **Ausência de linha = 0 somente dentro da janela coberta.**
- Janela obrigatória em `sus_meta(user=list(date_min, date_max, years_covered, years_excluded=c(2020,2021), years_missing))` e no `datapackage.json`. Anos fora de `years_covered` **não** são zeros.
- Removidos vs. versão anual: `year`, `sex`, `age_group`, `population`, `rate_100k`, `rate_100k_std`, `suppressed`, `pop_source`. Estratos sexo × idade ficam fora (sem denominador estratificado e alto risco de reidentificação no grão diário). Taxa padronizada por idade: fora do v1.
- Data sem `DTOBITO` válida ou residência ignorada: excluir e contar em `sus_meta(user=list(n_dropped_no_date, n_dropped_no_residence))`.

### 5b. Denominador `population_muni_year` (novo, pequeno, público)
Path: `data/public/gold/population_muni_year/v1.0.0/data.parquet` (sem partição; ~5.570 × 10 linhas). Colunas: `code_muni` int32, `year` int32, `population` int32 (>0), `pop_source` string. Chave única `code_muni, year`. Grade **completa** (todo município × todo ano coberto), para que município sem evento tenha taxa 0. Fonte = `data/reference/ibge_population_muni_year.parquet` já usado por Duto (só promover a público).

## 6. Taxas (calculadas pelo consumidor, nunca no gold diário)
- Período P (conjunto de dias dentro de `years_covered`): `rate_100k = Σ n_events(P) / Σ_anos population(ano) × (dias de P no ano / dias do ano) × 1e5` ⇒ taxa anualizada por 100 mil (pessoa-ano). Para P = anos inteiros reduz a `Σ n / Σ pop × 1e5`.
- `Σ pop` do período < 1000 pessoa-ano → taxa NA (instável). Município sem linha no período → n=0, taxa 0.
- UF/Brasil: somar contagens e populações (nunca média de taxas). Nunca somar `outcome`s (sobrepostos, §4).
- Fonte populacional: IBGE estimativas anuais (SIDRA 6579) + Censo 2022 para 2022–2023; não usar `pop_21/pop_25`.

## 7. Supressão de células pequenas (decisão proposta — confirmar com usuário, §11)
- **Gold diário: sem supressão** (`n_events` bruto). Mesma política já adotada para `health_climate_daily` (DATA_MODEL.md): no grão diário 1–4 é a forma natural da série; suprimir destrói o uso em DLNM/séries temporais, que é a razão do dataset. Risco marginal ≈ 0: os microdados SIM-DO (data, residência, causa, sexo, idade) já são públicos no DATASUS; o agregado diário sem sexo/idade revela menos que a fonte.
- **Supressão k=5 na exibição/agregação (Vitrine, obrigatório):** qualquer total mostrado (mapa, tooltip, tabela, download agregado) de um recorte município × período × desfecho com `0 < n < 5` → mostrar "<5" (cinza) e taxa oculta; nunca 0. Período mínimo exibido por município: **ano** (série diária do município só no gráfico de linha se Σ n do período ≥ 5; senão aviso). UF/Brasil não precisam (n grande).
- Alternativas rejeitadas: (a) publicar só n ≥ k no diário — elimina a maioria das linhas e enviesa a série (zeros e 1–4 indistinguíveis); (b) faixa mínima de população — exclui ~1/4 dos municípios (pequenos, justamente onde calor/vetoriais pesam) e não resolve o risco nos grandes; (c) agregar em região de saúde — perde a chave `code_muni` comum a todos os gold e o join com clima/ERA5.
- **`suicide_self_harm` e `mental_disorders`**: risco de exposição mediática maior; proposta = publicar igual (fonte já pública), mas Vitrine aplica k=5 também no tooltip diário. Alternativa conservadora: publicar esses dois só no grão mensal. **Decisão do usuário.**
- `check_small_cells.R` (Duto): o ramo `n_events` deixa de falhar em 1–4. Novo cheque: `n_events` int ≥1, sem NA, chave `code_muni,date,outcome` única, `date` ∉ anos excluídos, sem colunas `sex/age_group` (estratos proibidos no diário). Relatório (não falha) de nº de células 1–4 por desfecho para o Technical Validation.

## 8. Relação com `health_climate_daily` (por que outro dataset diário)
| | `health_climate_daily` | `climate_outcomes_muni_day` |
|---|---|---|
| município | **ocorrência** | **residência** (casa com o denominador → taxas) |
| desfechos | 3 colunas agregadas (`deaths_total` = 58 grupos, `resp`, `circ`) | 12 grupos específicos, sobrepostos, formato longo |
| clima | embutido (INMET) | não; join por `code_muni, date` com `health_climate_daily`/`env_era5_daily` |
| janela | 2018–2023 | 2012–2019, 2022–2023 (alvo) |
- Evidência concreta: Luciara-MT (5105309) falta no mart de ocorrência (0 óbitos ocorridos, 22 de residentes) e volta por residência.
- Não substitui o mart: DLNM existente continua por ocorrência; o novo serve taxas por desfecho e DLNM por residência.

## 9. Qualidade (Technical Validation)
- Reconciliação: `cardiovascular` (residência) vs `deaths_circ` (ocorrência) por UF × ano, anos comuns (2018, 2019, 2022, 2023): diferença esperada < 5%; fora disso investigar. **Não** comparar Σ desfechos com `deaths_total` (grupos se sobrepõem e conjuntos de CID diferem).
- % causa mal definida (R00-R99, `ill_defined`) por UF × ano: relatório no Technical Validation (sem coluna no gold); municípios com > 20% sinalizados no relatório.
- Completude: todo município IBGE aparece em `population_muni_year`; datas no gold ⊂ janela declarada; nº de óbitos descartados (sem data/residência) por UF.

## 10. Texto metodológico (paper, ~150 palavras, pt; **reescrito para o grão diário** — Pena porta depois)
> Selecionamos 12 grupos de causas de óbito sensíveis ao clima (doenças cardiovasculares, respiratórias, relacionadas ao calor e ao frio, diarreicas, dengue/vetoriais, malária, leptospirose, diabetes, transtornos mentais e suicídio), definidos por códigos CID-10 da causa básica no Sistema de Informações sobre Mortalidade (SIM-DO), com base na lista curada do pacote climasus4r. Os óbitos foram atribuídos ao município de residência e agregados por dia, formando séries diárias município × desfecho compatíveis com as variáveis climáticas. O período compreende 10 anos (2012–2019 e 2022–2023); 2020–2021 foram excluídos pela distorção da mortalidade durante a pandemia de COVID-19. Taxas por 100 mil habitantes são calculadas por período a partir de estimativas populacionais anuais do IBGE. As contagens diárias são publicadas sem estratificação por sexo ou idade, nível de detalhe inferior ao dos microdados públicos do SIM; na interface, totais de 1–4 óbitos são exibidos como "<5".

## 11. Pendências / decisões do usuário
1. **Confirmar política §7** (diário sem supressão + k=5 na exibição), em especial `suicide_self_harm`/`mental_disorders` (igual vs. mensal).
2. **Aprovar download SIM 2012–2017** (sem isso, 4 anos: 2018, 2019, 2022, 2023).
3. SIH em v2 ou fora do paper.
4. `docs/ORCHESTRATION.md` ainda cita `climate_outcomes_muni_year` / "× ano" — atualizar (não é arquivo da Sentinela).
5. Pena: §10 mudou (agregação diária, taxa por período, regra "<5").
