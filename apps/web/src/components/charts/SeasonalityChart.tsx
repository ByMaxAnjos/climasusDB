import { useEffect, useMemo, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { Metric } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

export interface SeasonalityRow {
  month: number; // 1-12
  value: number;
}

interface SeasonalityChartProps {
  rows: SeasonalityRow[];
  metric: Metric;
  muniLabel: string | null;
}

export function SeasonalityChart({ rows, metric, muniLabel }: SeasonalityChartProps) {
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
    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height: 260,
      marginLeft: 50,
      x: { label: null },
      y: { label, grid: true },
      marks: [
        Plot.barY(data, { x: "label", y: "value", fill: "#1d9bf0" }),
        Plot.tip(data, Plot.pointer({ x: "label", y: "value" })),
        Plot.ruleY([0]),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [data, metric, muniLabel, t]);

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {muniLabel ? t("charts:seasonality_title", { name: muniLabel }) : t("select_municipality")}
      </h3>
      <div ref={containerRef} />
      {muniLabel && data.length === 0 && <p className="page-lede">{t("charts:no_data")}</p>}
      {!muniLabel && <p className="page-lede">{t("charts:seasonality_hint")}</p>}
      {muniLabel && data.length > 0 && (
        <>
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
