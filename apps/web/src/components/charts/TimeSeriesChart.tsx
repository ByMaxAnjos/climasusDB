import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { HealthClimateRow, Metric } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

interface TimeSeriesChartProps {
  rows: HealthClimateRow[];
  metric: Metric;
  muniLabel: string | null;
  height?: number;
}

export function TimeSeriesChart({ rows, metric, muniLabel, height = 260 }: TimeSeriesChartProps) {
  const { t } = useTranslation();
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    container.innerHTML = "";
    if (rows.length === 0) return;

    const label = t(`metric.${metric}`);
    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height,
      marginLeft: 50,
      x: { type: "utc", label: t("date_axis") },
      y: { label, grid: true },
      marks: [
        Plot.lineY(rows, { x: (d) => new Date(d.date), y: metric, stroke: "#ff6b4a" }),
        Plot.dot(rows, { x: (d) => new Date(d.date), y: metric, r: 2, fill: "#ff6b4a" }),
        Plot.tip(rows, Plot.pointerX({ x: (d) => new Date(d.date), y: metric })),
        Plot.ruleY([0]),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [rows, metric, height, t]);

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {muniLabel ? t("time_series_title", { name: muniLabel }) : t("select_municipality")}
      </h3>
      <div ref={containerRef} />
      {rows.length > 0 && (
        <>
          <ExportButtons
            rows={rows as unknown as Record<string, unknown>[]}
            getSvg={() => containerRef.current?.querySelector("svg") ?? null}
            baseFilename={`serie_temporal_${metric}`}
          />
          <InterpretGuide textKey="charts:interpret.timeseries" />
        </>
      )}
    </div>
  );
}
