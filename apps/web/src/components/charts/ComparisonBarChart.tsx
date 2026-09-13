import { useEffect, useMemo, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { Metric } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

const TOP_N = 15;

interface ComparisonBarChartProps {
  values: Record<number, number>; // code_muni -> valor, já filtrado por Região/Estado
  muniNames: Record<number, string>;
  metric: Metric;
  scopeLabel: string;
}

export function ComparisonBarChart({ values, muniNames, metric, scopeLabel }: ComparisonBarChartProps) {
  const { t } = useTranslation(["common", "charts"]);
  const containerRef = useRef<HTMLDivElement>(null);

  const rows = useMemo(
    () =>
      Object.entries(values)
        .map(([code, value]) => ({ code_muni: Number(code), name_muni: muniNames[Number(code)] ?? code, value }))
        .filter((r) => Number.isFinite(r.value))
        .sort((a, b) => b.value - a.value)
        .slice(0, TOP_N),
    [values, muniNames],
  );

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    container.innerHTML = "";
    if (rows.length === 0) return;

    const label = t(`metric.${metric}`);
    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height: Math.max(220, rows.length * 26),
      marginLeft: 170,
      x: { label, grid: true },
      y: { label: null },
      marks: [
        Plot.barX(rows, { y: "name_muni", x: "value", fill: "#0e7a5f", sort: { y: "-x" } }),
        Plot.tip(rows, Plot.pointer({ y: "name_muni", x: "value" })),
        Plot.ruleX([0]),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [rows, metric, t]);

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>{t("charts:comparison_title", { scope: scopeLabel })}</h3>
      <div
        ref={containerRef}
        role="img"
        aria-label={`${t("charts:comparison_title", { scope: scopeLabel })} — ${t(`metric.${metric}`)}`}
      />
      {rows.length === 0 && <p className="page-lede">{t("charts:no_data")}</p>}
      {rows.length > 0 && (
        <>
          <table className="visually-hidden">
            <caption>{t("charts:comparison_title", { scope: scopeLabel })}</caption>
            <thead>
              <tr>
                <th>{t("municipality")}</th>
                <th>{t(`metric.${metric}`)}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.code_muni}>
                  <td>{row.name_muni}</td>
                  <td>{row.value}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <ExportButtons
            rows={rows}
            getSvg={() => containerRef.current?.querySelector("svg") ?? null}
            baseFilename={`comparacao_${metric}`}
          />
          <InterpretGuide textKey="charts:interpret.comparison" />
        </>
      )}
    </div>
  );
}
