# Vitrine — adaptação ao grão diário

Contrato lido: docs/specs/climate_outcomes.md, §§5–7 (mudança para climate_outcomes_muni_day + population_muni_year).

Implementação em apps/web/src:
- db.ts: registro opcional dos dois datasets; leitura dos datapackages das partições e interseção conservadora dos anos cobertos. Sem metadados válidos, não inventa cobertura/zeros. Exclui 2020–2021 e limita aos últimos 10 anos cobertos.
- types.ts: schema diário bruto e denominador anual separado; removidas as antigas colunas anuais/estratos/taxas padronizadas.
- pages/ClimateOutcomesPanel.tsx: eventos diários agregados por município/ano antes da exibição. Grade populacional inclui municípios sem eventos; ausência de evento só vira zero dentro do calendário coberto. Total municipal entre 1 e 4 vira <5 cinza, sem valor numérico nem taxa no resultado da consulta. Zero verdadeiro permanece zero.
- Taxas anualizadas = eventos / exposição em pessoas-ano × 100 mil; exposição ponderada pelos dias cobertos em cada ano, com ano bissexto. Exposição inferior a 1000 ou população ausente implica taxa indisponível. UF/Brasil somam contagens brutas e exposições, sem somar desfechos e sem média de taxas.
- i18n/climate-outcomes.ts: textos pt/en/es adaptados; removida taxa padronizada. Mantidos seletores rotulados, tabelas com captions e cabeçalhos, aria-live.

Validação: npm run build aprovado (TypeScript + Vite; aviso de bundle >500 kB). Oito cenários executados em DuckDB com o SQL extraído do componente: soma municipal 2+2 suprimida; limiar 5 visível; população pequena; população ausente; zero esparso; ano bissexto; período parcial; agregado UF sem supressão prévia dos municípios. Script: /tmp/check_climate_daily.py.

Limites: interface permanece anual (período mínimo municipal da spec), sem gráfico/tooltip diário ou download agregado. Janela nacional conservadora usa cobertura comum às partições. Integração no navegador com os novos parquets/metadados ainda depende da publicação pelo Duto. Sem dependências novas e sem commit.
