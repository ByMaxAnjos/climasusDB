import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { query, DIM_STATION_FILE, CLIMATE_OUTCOMES_FILE, isClimateOutcomesAvailable, climateOutcomesCoverage, POPULATION_MUNI_YEAR_FILE } from "../db";
import { CLIMATE_OUTCOMES, type ClimateOutcome } from "../types";

interface AnnualRow { year: number; n_events: number | null; population: number | null; suppressed: boolean; rate_100k: number | null; }
interface Result { key: string; state: "ready" | "unavailable" | "error"; years: number; municipal: AnnualRow[]; brazil: AnnualRow[]; uf: AnnualRow[]; }
export function ClimateOutcomesPanel({ municipality, uf }: { municipality: { code: number; name: string } | null; uf: string | null }) {
  const { t, i18n } = useTranslation();
  const [outcome, setOutcome] = useState<ClimateOutcome>("cardiovascular");
  const [result, setResult] = useState<Result | null>(null);
  const key = `${outcome}:${municipality?.code ?? ""}:${uf ?? ""}`;
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const base: Result = { key, state: "ready", years: 0, municipal: [], brazil: [], uf: [] };
      try {
        await query(`SELECT 1 FROM '${DIM_STATION_FILE}' LIMIT 1`);
        if (!isClimateOutcomesAvailable()) { if (!cancelled) setResult({ ...base, state: "unavailable" }); return; }
        const coverage = await climateOutcomesCoverage();
        const periods = coverage.years.map(year => ({ year,
          start: coverage.dateMin > `${year}-01-01` ? coverage.dateMin : `${year}-01-01`,
          end: coverage.dateMax < `${year}-12-31` ? coverage.dateMax : `${year}-12-31`,
        })).filter(p => p.start <= p.end);
        if (!periods.length) { if (!cancelled) setResult(base); return; }
        const calendar = periods.map(p => `SELECT ${p.year} AS year, DATE '${p.start}' AS start_date, DATE '${p.end}' AS end_date`).join(" UNION ALL ");
        // A population row is the municipality/year grid. Sparse missing events are
        // zero ONLY in the covered calendar; missing population remains unavailable.
        const aggregate = (extra = "", municipal = false) => query<AnnualRow>(`WITH calendar AS (${calendar}),
          events AS (
            SELECT d.code_muni, c.year, sum(d.n_events) AS n_events
            FROM '${CLIMATE_OUTCOMES_FILE}' d JOIN calendar c ON d.date BETWEEN c.start_date AND c.end_date
            WHERE d.system = 'SIM' AND d.outcome = '${outcome}' GROUP BY d.code_muni, c.year
          ), cells AS (
            SELECT p.code_muni, c.year, coalesce(e.n_events, 0) AS n_events,
              p.population * ((date_diff('day', c.start_date, c.end_date) + 1)::DOUBLE /
                date_diff('day', make_date(c.year, 1, 1), make_date(c.year + 1, 1, 1))) AS person_years
            FROM '${POPULATION_MUNI_YEAR_FILE}' p JOIN calendar c ON p.year = c.year
            LEFT JOIN events e ON e.code_muni = p.code_muni AND e.year = c.year
            WHERE TRUE ${extra}
          ), totals AS (
            SELECT year, sum(n_events) AS raw_events,
              CASE WHEN count(person_years) <> count(*) OR min(person_years) <= 0 THEN NULL ELSE sum(person_years) END AS population
            FROM cells GROUP BY year
          ) SELECT year,
            CASE WHEN ${municipal} AND raw_events BETWEEN 1 AND 4 THEN NULL ELSE CAST(raw_events AS DOUBLE) END AS n_events,
            (${municipal} AND raw_events BETWEEN 1 AND 4) AS suppressed, population,
            CASE WHEN (${municipal} AND raw_events BETWEEN 1 AND 4) OR population < 1000 THEN NULL
              ELSE raw_events * 100000.0 / population END AS rate_100k
          FROM totals ORDER BY year`);
        const ufCodes: Record<string, number> = { RO:11, AC:12, AM:13, RR:14, PA:15, AP:16, TO:17, MA:21, PI:22, CE:23, RN:24, PB:25, PE:26, AL:27, SE:28, BA:29, MG:31, ES:32, RJ:33, SP:35, PR:41, SC:42, RS:43, MS:50, MT:51, GO:52, DF:53 };
        const [municipal, brazil, state] = await Promise.all([
          municipality ? aggregate(`AND p.code_muni = ${Number(municipality.code)}`, true) : Promise.resolve([]),
          aggregate(),
          uf && ufCodes[uf] ? aggregate(`AND floor(p.code_muni / 100000) = ${ufCodes[uf]}`) : Promise.resolve([]),
        ]);
        if (!cancelled) setResult({ ...base, years: periods.length, municipal, brazil, uf: state });
      } catch (err) { console.error("Climate outcomes:", err); if (!cancelled) setResult({ ...base, state: "error" }); }
    })();
    return () => { cancelled = true; };
  }, [key, outcome, municipality?.code, uf]);
  const current = result?.key === key ? result : null;
  const format = (value: number | null | undefined) => value == null ? t("climate:missing") : Number(value).toLocaleString(i18n.language, { maximumFractionDigits: 2 });
  function annualTable(rows: AnnualRow[], label: string) {
    return <section><h3>{label}</h3>{rows.length === 0 ? <p>{t("climate:empty")}</p> : <table className="data-table">
      <caption>{t("climate:title")} — {t(`climate:${outcome}`)} — {label}</caption>
      <thead><tr>{["year", "count", "population", "rate"].map(column => <th scope="col" key={column}>{t(`climate:${column}`)}</th>)}</tr></thead>
      <tbody>{rows.map(row => { const cell = row; return <tr key={row.year}><th scope="row">{row.year}</th><td style={cell.suppressed ? { color: "var(--muted)" } : undefined}>{cell.suppressed ? "<5" : format(row.n_events)}</td><td>{format(row.population)}</td><td>{format(cell.suppressed ? null : row.rate_100k)}</td></tr>; })}</tbody>
    </table>}</section>;
  }
  return <div style={{ flex: 1, padding: 24, overflow: "auto" }}>
    <h2>{t("climate:title")}</h2>
    <label htmlFor="climate-outcome">{t("climate:outcome")}: <select id="climate-outcome" value={outcome} onChange={e => setOutcome(e.target.value as ClimateOutcome)}>{CLIMATE_OUTCOMES.map(value => <option key={value} value={value}>{t(`climate:${value}`)}</option>)}</select></label>
    <p>{t("climate:privacy")}</p>
    <div role="status" aria-live="polite">{!current ? t("loading") : current.state === "unavailable" ? t("climate:unavailable") : current.state === "error" ? t("error") : t("climate:window", { count: current.years })}</div>
    {current?.state === "ready" && <><div style={{ overflowX: "auto" }}>{municipality ? annualTable(current.municipal, municipality.name) : <p>{t("climate:select")}</p>}{uf && annualTable(current.uf, `${t("climate:state")} — ${uf}`)}{annualTable(current.brazil, t("climate:brazil"))}</div></>}
  </div>;
}
