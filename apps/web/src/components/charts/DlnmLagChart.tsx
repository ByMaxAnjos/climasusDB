import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { DlnmLagRow } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

interface DlnmLagChartProps {
  rows: DlnmLagRow[]; // 1 UF, grão lag (0..lag_max), na exposição do p75 — ver docs/DATA_MODEL.md
  ufLabel: string | null;
}

// Espelha climasus4r:::.plot_dlnm_lag(): risco relativo isolado por dia de
// defasagem (barras + IC) na exposição do percentil 75.
export function DlnmLagChart({ rows, ufLabel }: DlnmLagChartProps) {
  const { t } = useTranslation(["common", "charts"]);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    container.innerHTML = "";
    if (rows.length === 0) return;

    const sorted = [...rows].sort((a, b) => a.lag - b.lag);

    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height: 280,
      marginLeft: 50,
      x: { label: t("charts:dlnm.lag_axis") },
      y: { label: t("charts:dlnm.rr_axis"), grid: true },
      marks: [
        Plot.ruleX(sorted, { x: "lag", y1: "lo", y2: "hi", stroke: "#1d9bf0", strokeOpacity: 0.6 }),
        Plot.dot(sorted, { x: "lag", y: "rr", r: 3, fill: "#ff6b4a" }),
        Plot.ruleY([1], { stroke: "#555", strokeDasharray: "4,3" }),
        Plot.tip(sorted, Plot.pointerX({ x: "lag", y: "rr", title: (d) => `lag ${d.lag}d — RR ${d.rr.toFixed(3)} [${d.lo.toFixed(3)}, ${d.hi.toFixed(3)}]` })),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [rows, t]);

  const hasAutocorr = rows.length > 0 && rows[0].has_autocorr;

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {ufLabel ? t("charts:dlnm.lag_title", { name: ufLabel }) : t("select_municipality")}
      </h3>
      {ufLabel && rows.length === 0 && <p className="page-lede">{t("charts:no_data")}</p>}
      <div ref={containerRef} />
      {ufLabel && rows.length > 0 && (
        <>
          {hasAutocorr && (
            <p className="badge badge-muted" style={{ marginTop: 8 }}>
              {t("charts:dlnm.autocorr_warning")}
            </p>
          )}
          <ExportButtons
            rows={rows as unknown as Record<string, unknown>[]}
            getSvg={() => containerRef.current?.querySelector("svg") ?? null}
            baseFilename={`dlnm_lag_${ufLabel}`}
          />
          <InterpretGuide textKey="charts:interpret.dlnm_lag" />
        </>
      )}
    </div>
  );
}
