import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { HealthClimateRow, Metric } from "./types";

interface TimeSeriesProps {
  rows: HealthClimateRow[];
  metric: Metric;
  muniLabel: string | null;
}

export function TimeSeries({ rows, metric, muniLabel }: TimeSeriesProps) {
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
      height: 260,
      marginLeft: 50,
      x: { type: "utc", label: "data" },
      y: { label, grid: true },
      marks: [
        Plot.lineY(rows, { x: (d) => new Date(d.date), y: metric, stroke: "#c0392b" }),
        Plot.ruleY([0]),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [rows, metric, t]);

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {muniLabel ? t("time_series_title", { name: muniLabel }) : t("select_municipality")}
      </h3>
      <div ref={containerRef} />
    </div>
  );
}
