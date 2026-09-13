import { useEffect, useMemo, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { Metric } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

export interface SeasonalityRow {
  year: number;
  month: number; // 1-12
  value: number;
}

interface SeasonalityChartProps {
  rows: SeasonalityRow[];
  metric: Metric;
  muniLabel: string | null;
  height?: number;
}

export function SeasonalityChart({ rows, metric, muniLabel, height = 260 }: SeasonalityChartProps) {
  const { t } = useTranslation(["common", "charts"]);
  const containerRef = useRef<HTMLDivElement>(null);
  const monthLabels = t("charts:months", { returnObjects: true, defaultValue: [] }) as string[];

  const data = useMemo(
    () => rows.map((r) => ({ ...r, label: monthLabels[r.month - 1] ?? String(r.month) })),
    [rows, monthLabels],
  );

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    container.innerHTML = "";
    if (!muniLabel || data.length === 0) return;

    const label = t(`metric.${metric}`);
    // Boxplot por mês (um ponto por ano-mês) em vez de só a média — mostra a
    // dispersão entre anos, não apenas o valor típico.
    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height,
      marginLeft: 50,
      x: { label: null, domain: monthLabels.length ? monthLabels : undefined },
      y: { label, grid: true },
      marks: [Plot.boxY(data, { x: "label", y: "value", fill: "#1d9bf0" }), Plot.ruleY([0])],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [data, metric, muniLabel, height, monthLabels, t]);

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {muniLabel ? t("charts:seasonality_title", { name: muniLabel }) : t("select_municipality")}
      </h3>
      <div
        ref={containerRef}
        role="img"
        aria-label={`${muniLabel ? t("charts:seasonality_title", { name: muniLabel }) : t("select_municipality")} — ${t(`metric.${metric}`)}`}
      />
      {muniLabel && data.length === 0 && <p className="page-lede">{t("charts:no_data")}</p>}
      {!muniLabel && <p className="page-lede">{t("charts:seasonality_hint")}</p>}
      {muniLabel && data.length > 0 && (
        <>
          <table className="visually-hidden">
            <caption>{t("charts:seasonality_title", { name: muniLabel })}</caption>
            <thead>
              <tr>
                <th>{t("charts:month_column")}</th>
                <th>{t("charts:year_column")}</th>
                <th>{t(`metric.${metric}`)}</th>
              </tr>
            </thead>
            <tbody>
              {data.map((row) => (
                <tr key={`${row.year}-${row.month}`}>
                  <td>{row.label}</td>
                  <td>{row.year}</td>
                  <td>{row.value}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <ExportButtons
            rows={data}
            getSvg={() => containerRef.current?.querySelector("svg") ?? null}
            baseFilename={`sazonalidade_${metric}`}
          />
          <InterpretGuide textKey="charts:interpret.seasonality" />
        </>
      )}
    </div>
  );
}
