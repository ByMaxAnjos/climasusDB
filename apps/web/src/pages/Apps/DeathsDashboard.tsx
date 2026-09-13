import { useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import { HEALTH_CLIMATE_FILE, query } from "../../db";
import { Link } from "../../router";

interface SummaryRow {
  rows: number;
  municipalities: number;
  min_date: string;
  max_date: string;
  deaths_total: number;
  deaths_resp: number;
  deaths_circ: number;
}

interface MonthlyRow {
  month: string;
  deaths_total: number;
  deaths_resp: number;
  deaths_circ: number;
  tmax: number;
  precip: number;
}

interface TopMuniRow {
  name_muni: string;
  deaths_total: number;
  tmax: number;
  precip: number;
}

type ClimateVariable = "tmax" | "precip";

function pearson(rows: MonthlyRow[], xKey: ClimateVariable): number | null {
  const pairs = rows
    .map((row) => ({ x: row[xKey], y: row.deaths_total }))
    .filter((row) => Number.isFinite(row.x) && Number.isFinite(row.y));
  if (pairs.length < 3) return null;
  const meanX = pairs.reduce((sum, row) => sum + row.x, 0) / pairs.length;
  const meanY = pairs.reduce((sum, row) => sum + row.y, 0) / pairs.length;
  let numerator = 0;
  let denomX = 0;
  let denomY = 0;
  for (const row of pairs) {
    const dx = row.x - meanX;
    const dy = row.y - meanY;
    numerator += dx * dy;
    denomX += dx * dx;
    denomY += dy * dy;
  }
  const denom = Math.sqrt(denomX * denomY);
  return denom === 0 ? null : numerator / denom;
}

function formatNumber(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return "—";
  return value.toLocaleString();
}

function correlationStrength(r: number): "negligible" | "weak" | "moderate" | "strong" {
  const abs = Math.abs(r);
  if (abs < 0.2) return "negligible";
  if (abs < 0.4) return "weak";
  if (abs < 0.6) return "moderate";
  return "strong";
}

export function DeathsDashboard() {
  const { t } = useTranslation("docs");
  const [summary, setSummary] = useState<SummaryRow | null>(null);
  const [monthly, setMonthly] = useState<MonthlyRow[]>([]);
  const [topMunis, setTopMunis] = useState<TopMuniRow[]>([]);
  const [climateVariable, setClimateVariable] = useState<ClimateVariable>("tmax");
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const groupsRef = useRef<HTMLDivElement>(null);
  const trendRef = useRef<HTMLDivElement>(null);
  const associationRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [summaryRows, monthlyRows, topRows] = await Promise.all([
          query<SummaryRow>(
            `SELECT
               CAST(COUNT(*) AS DOUBLE) AS rows,
               CAST(COUNT(DISTINCT code_muni) AS DOUBLE) AS municipalities,
               strftime(min(date), '%Y-%m-%d') AS min_date,
               strftime(max(date), '%Y-%m-%d') AS max_date,
               CAST(SUM(deaths_total) AS DOUBLE) AS deaths_total,
               CAST(SUM(deaths_resp) AS DOUBLE) AS deaths_resp,
               CAST(SUM(deaths_circ) AS DOUBLE) AS deaths_circ
             FROM '${HEALTH_CLIMATE_FILE}'`,
          ),
          query<MonthlyRow>(
            `SELECT
               strftime(date, '%Y-%m') AS month,
               CAST(SUM(deaths_total) AS DOUBLE) AS deaths_total,
               CAST(SUM(deaths_resp) AS DOUBLE) AS deaths_resp,
               CAST(SUM(deaths_circ) AS DOUBLE) AS deaths_circ,
               CAST(AVG(tmax) AS DOUBLE) AS tmax,
               CAST(AVG(precip) AS DOUBLE) AS precip
             FROM '${HEALTH_CLIMATE_FILE}'
             GROUP BY month
             ORDER BY month`,
          ),
          query<TopMuniRow>(
            `SELECT
               name_muni,
               CAST(SUM(deaths_total) AS DOUBLE) AS deaths_total,
               CAST(AVG(tmax) AS DOUBLE) AS tmax,
               CAST(AVG(precip) AS DOUBLE) AS precip
             FROM '${HEALTH_CLIMATE_FILE}'
             GROUP BY code_muni, name_muni
             ORDER BY deaths_total DESC
             LIMIT 10`,
          ),
        ]);
        if (cancelled) return;
        setSummary(summaryRows[0] ?? null);
        setMonthly(monthlyRows);
        setTopMunis(topRows);
        setStatus("ready");
      } catch (err) {
        console.error("Falha ao carregar dashboard de óbitos:", err);
        if (!cancelled) setStatus("error");
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const groupRows = useMemo(() => {
    if (!summary) return [];
    return [
      { group: t("deaths_dashboard.groups.total"), value: summary.deaths_total, color: "#0e7a5f" },
      { group: t("deaths_dashboard.groups.resp"), value: summary.deaths_resp, color: "#1d9bf0" },
      { group: t("deaths_dashboard.groups.circ"), value: summary.deaths_circ, color: "#ff6b4a" },
    ];
  }, [summary, t]);

  const monthlyPlotRows = useMemo(
    () => monthly.map((row) => ({ ...row, date: new Date(`${row.month}-01T00:00:00`) })),
    [monthly],
  );

  const association = useMemo(() => pearson(monthly, climateVariable), [monthly, climateVariable]);

  useEffect(() => {
    const container = groupsRef.current;
    if (!container || groupRows.length === 0) return;
    container.innerHTML = "";
    const plot = Plot.plot({
      width: container.clientWidth || 720,
      height: 220,
      marginLeft: 190,
      x: { label: t("deaths_dashboard.deaths_axis_total"), grid: true },
      y: { label: null },
      color: { range: groupRows.map((row) => row.color) },
      marks: [
        Plot.barX(groupRows, { x: "value", y: "group", fill: "group", sort: { y: "-x" } }),
        Plot.text(groupRows, { x: "value", y: "group", text: (d) => formatNumber(d.value), dx: 6, textAnchor: "start" }),
        Plot.ruleX([0]),
      ],
    });
    container.appendChild(plot);
    return () => plot.remove();
  }, [groupRows, t]);

  useEffect(() => {
    const container = trendRef.current;
    if (!container || monthlyPlotRows.length === 0) return;
    container.innerHTML = "";
    const plot = Plot.plot({
      width: container.clientWidth || 720,
      height: 280,
      marginLeft: 64,
      x: { type: "utc", label: t("deaths_dashboard.month_axis") },
      y: { label: t("deaths_dashboard.deaths_axis_monthly"), grid: true },
      marks: [
        Plot.areaY(monthlyPlotRows, { x: "date", y: "deaths_total", fill: "#0e7a5f", fillOpacity: 0.16 }),
        Plot.lineY(monthlyPlotRows, { x: "date", y: "deaths_total", stroke: "#0e7a5f", strokeWidth: 2 }),
        Plot.dot(monthlyPlotRows, { x: "date", y: "deaths_total", r: 2.5, fill: "#0e7a5f" }),
        Plot.tip(monthlyPlotRows, Plot.pointerX({ x: "date", y: "deaths_total" })),
        Plot.ruleY([0]),
      ],
    });
    container.appendChild(plot);
    return () => plot.remove();
  }, [monthlyPlotRows, t]);

  useEffect(() => {
    const container = associationRef.current;
    if (!container || monthly.length === 0) return;
    container.innerHTML = "";
    const label = t(`deaths_dashboard.climate.${climateVariable}`);
    const plot = Plot.plot({
      width: container.clientWidth || 720,
      height: 300,
      marginLeft: 64,
      x: { label, grid: true },
      y: { label: t("deaths_dashboard.deaths_axis_monthly"), grid: true },
      marks: [
        Plot.dot(monthly, {
          x: climateVariable,
          y: "deaths_total",
          r: 4,
          fill: "#ff6b4a",
          fillOpacity: 0.76,
          title: (d) => `${d.month}\n${label}: ${formatNumber(d[climateVariable])}\n${t("deaths_dashboard.deaths_axis_monthly")}: ${formatNumber(d.deaths_total)}`,
        }),
        Plot.linearRegressionY(monthly, { x: climateVariable, y: "deaths_total", stroke: "#052e2b" }),
      ],
    });
    container.appendChild(plot);
    return () => plot.remove();
  }, [monthly, climateVariable, t]);

  return (
    <div className="page deaths-dashboard">
      <p style={{ marginTop: 0 }}>
        <Link to="/apps">← {t("apps_title")}</Link>
      </p>
      <div className="eyebrow">{t("deaths_dashboard.eyebrow")}</div>
      <h2 style={{ margin: "8px 0 12px 0" }}>{t("deaths_dashboard.title")}</h2>
      <p className="page-lede" style={{ maxWidth: 860 }}>{t("deaths_dashboard.lede")}</p>

      {status === "loading" && <p className="page-lede">{t("deaths_dashboard.loading")}</p>}
      {status === "error" && <p style={{ color: "var(--heat)" }}>{t("deaths_dashboard.error")}</p>}

      {status === "ready" && summary && (
        <>
          <section className="dashboard-kpis" aria-label={t("deaths_dashboard.kpis_label")}>
            <div>
              <span className="eyebrow">{t("deaths_dashboard.kpis.deaths")}</span>
              <strong>{formatNumber(summary.deaths_total)}</strong>
            </div>
            <div>
              <span className="eyebrow">{t("deaths_dashboard.kpis.municipalities")}</span>
              <strong>{formatNumber(summary.municipalities)}</strong>
            </div>
            <div>
              <span className="eyebrow">{t("deaths_dashboard.kpis.period")}</span>
              <strong>{summary.min_date} · {summary.max_date}</strong>
            </div>
            <div>
              <span className="eyebrow">{t("deaths_dashboard.kpis.rows")}</span>
              <strong>{formatNumber(summary.rows)}</strong>
            </div>
          </section>

          <section className="dashboard-section">
            <h3>{t("deaths_dashboard.groups_title")}</h3>
            <p className="page-lede">{t("deaths_dashboard.groups_note")}</p>
            <div ref={groupsRef} role="img" aria-label={t("deaths_dashboard.groups_title")} />
            <p className="dashboard-chart-note">{t("deaths_dashboard.groups_legend")}</p>
            <table className="visually-hidden">
              <caption>{t("deaths_dashboard.groups_title")}</caption>
              <tbody>
                {groupRows.map((row) => (
                  <tr key={row.group}>
                    <td>{row.group}</td>
                    <td>{row.value}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          <section className="dashboard-section">
            <h3>{t("deaths_dashboard.trend_title")}</h3>
            <p className="page-lede">{t("deaths_dashboard.trend_note")}</p>
            <div ref={trendRef} role="img" aria-label={t("deaths_dashboard.trend_title")} />
            <p className="dashboard-chart-note">{t("deaths_dashboard.trend_legend")}</p>
            <table className="visually-hidden">
              <caption>{t("deaths_dashboard.trend_title")}</caption>
              <thead>
                <tr>
                  <th>{t("deaths_dashboard.month_axis")}</th>
                  <th>{t("deaths_dashboard.kpis.deaths")}</th>
                </tr>
              </thead>
              <tbody>
                {monthly.map((row) => (
                  <tr key={row.month}>
                    <td>{row.month}</td>
                    <td>{row.deaths_total}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          <section className="dashboard-section">
            <div className="dashboard-section-header">
              <div>
                <h3>{t("deaths_dashboard.association_title")}</h3>
                <p className="page-lede">{t("deaths_dashboard.association_note")}</p>
              </div>
              <label htmlFor="climate-variable">
                {t("deaths_dashboard.climate_label")}{" "}
                <select id="climate-variable" value={climateVariable} onChange={(event) => setClimateVariable(event.target.value as ClimateVariable)}>
                  <option value="tmax">{t("deaths_dashboard.climate.tmax")}</option>
                  <option value="precip">{t("deaths_dashboard.climate.precip")}</option>
                </select>
              </label>
            </div>
            <p className="dashboard-correlation">
              {t("deaths_dashboard.correlation")}:{" "}
              {association == null
                ? "—"
                : `${association.toFixed(2)} (${t(`deaths_dashboard.correlation_direction.${association >= 0 ? "positive" : "negative"}`)} · ${t(`deaths_dashboard.correlation_strength.${correlationStrength(association)}`)})`}
            </p>
            <div
              ref={associationRef}
              role="img"
              aria-label={`${t("deaths_dashboard.association_title")} — ${t(`deaths_dashboard.climate.${climateVariable}`)}`}
            />
            <p className="dashboard-chart-note">{t("deaths_dashboard.association_legend")}</p>
            <p className="dashboard-chart-note">{t("deaths_dashboard.correlation_caveat")}</p>
            <table className="visually-hidden">
              <caption>{t("deaths_dashboard.association_title")}</caption>
              <thead>
                <tr>
                  <th>{t(`deaths_dashboard.climate.${climateVariable}`)}</th>
                  <th>{t("deaths_dashboard.kpis.deaths")}</th>
                </tr>
              </thead>
              <tbody>
                {monthly.map((row) => (
                  <tr key={row.month}>
                    <td>{row[climateVariable]}</td>
                    <td>{row.deaths_total}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          <section className="dashboard-section">
            <h3>{t("deaths_dashboard.table_title")}</h3>
            <p className="page-lede">{t("deaths_dashboard.table_note")}</p>
            <table className="data-table">
              <thead>
                <tr>
                  <th>{t("deaths_dashboard.table.municipality")}</th>
                  <th>{t("deaths_dashboard.table.deaths")}</th>
                  <th>{t("deaths_dashboard.table.tmax")}</th>
                  <th>{t("deaths_dashboard.table.precip")}</th>
                </tr>
              </thead>
              <tbody>
                {topMunis.map((row) => (
                  <tr key={row.name_muni}>
                    <td>{row.name_muni}</td>
                    <td>{formatNumber(row.deaths_total)}</td>
                    <td>{row.tmax.toFixed(1)}</td>
                    <td>{row.precip.toFixed(1)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
    </div>
  );
}
