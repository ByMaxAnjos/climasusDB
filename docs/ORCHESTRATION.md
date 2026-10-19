# Orquestração de agentes — climasusDB

Especialistas base: `../agents/` (governança em `../agents/agent-governance.instructions.md`). Idioma: pt-BR.

## Economia de modelos
| Tarefa | Agente/modelo |
|---|---|
| Escrita científica, revisão, decisões epidemiológicas | Claude Code |
| Código R mecânico (pipeline), TypeScript/React, deploy, QA | Codex |
Regra: nunca delegar leitura ampla a quem só edita; passe caminhos exatos. Respostas curtas; resultados em arquivos, não no chat.

## Dois clusters (workspaces)
- **climasusDB-Plataforma**: Sentinela (Opus, dono da spec), Duto, Vitrine, Selo (Codex).
- **climasusDB-Paper**: Pena (Sonnet), Lupa (Opus). Mesmo repositório; escrevem só em `docs/manuscript/` e `docs/reviews/`.
- Contrato entre clusters = arquivos: `docs/specs/climate_outcomes.md`, `docs/DATA_MODEL.md` e contagens finais do gold. Lupa recusa número fora deles. Mudança de escopo: Pena → `Sentinela @ climasusDB-Plataforma`.

## Time A — Paper (Scientific Data) · arquivo: `docs/manuscript/climasusdb_paper_scientific_data.md`
- **Pena** (Claude, Redator): escreve/edita seções.
- **Lupa** (Claude, Revisor): revisão estilo Sci Data + verificação de referências.
- **Sentinela** (Claude, Epidemiologista): define desfechos sensíveis ao clima, janela de anos e regras de privacidade.

## Time B — Ingestão climasus4r → climasusDB
- **Duto** (Codex, Ingestor): implementa o dataset gold de desfechos; usa `../climasus4r/R`.

## Time C — Plataforma (https://climasusdb.pages.dev/, R2)
- **Vitrine** (Codex, Web): `apps/web/src` — indicador "Explorar" por desfecho.
- **Selo** (Codex, QA/Deploy): build, a11y, performance, deploy Cloudflare Pages/R2.

## Indicador "Desfechos sensíveis ao clima" (pedido central)
- Grupos de CID: `climasus4r::list_disease_groups(climate_sensitive_only=TRUE)`, `sus_data_cid_select()`, filtro `sus_data_filter_cid(disease_group=...)`.
- Saída: por desfecho × município × ano → contagem, taxa/100 mil hab., (SIM óbitos; SIH internações se disponível).
- Janela: últimos 10 anos disponíveis **excluindo 2020–2021 (COVID-19)** — Sentinela confirma o intervalo exato.
- Contrato novo: `data/public/gold/climate_outcomes_muni_year/v{SEMVER}/uf={UF}/data.parquet`, escrito com `climasus4r::write_parquet_climasus()` (zstd, chunk 1e5, ordenado). Documentar em `docs/DATA_MODEL.md`; supressão de células pequenas (`pipelines/R/check_small_cells.R`).
- Fluxo: Sentinela (spec) → Duto (dados) → Vitrine (UI) → Selo (deploy) ; Pena/Lupa escrevem Methods/Data Records/Technical Validation com a mesma spec.

## Regras de convivência (evita conflito de edição)
- Pena/Lupa: só `docs/manuscript/`, `docs/reviews/`. Duto: só `pipelines/R/`, `docs/DATA_MODEL.md`. Vitrine: só `apps/web/src`. Selo: só `infra/`, build e relatórios em `docs/reviews/`.
- Sem rodar `make national` nem downloads longos sem aprovação do usuário. Sem commit/push sem pedido.
- Canal de especificação: `docs/specs/climate_outcomes.md` (Sentinela é dono).
