import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { DlnmExposureRow } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

interface DlnmOverallChartProps {
  rows: DlnmExposureRow[]; // curva completa (grade fina) de 1 UF, ver docs/DATA_MODEL.md
  ufLabel: string | null;
}

// Espelha climasus4r:::.plot_dlnm_overall() (sus_mod_plot_dlnm.R): linha
// suave (grade de 100 pontos) + faixa de IC 95% + linha de referência RR=1 +
// marcadores nos percentis reportados por sus_mod_dlnm() (coluna `pct`).
export function DlnmOverallChart({ rows, ufLabel }: DlnmOverallChartProps) {
  const { t } = useTranslation(["common", "charts"]);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    container.innerHTML = "";
    if (rows.length === 0) return;

    const sorted = [...rows].sort((a, b) => a.exposure - b.exposure);
    const markers = sorted.filter((r) => r.pct != null);

    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height: 280,
      marginLeft: 50,
      x: { label: t("charts:dlnm.exposure_axis") },
      y: { label: t("charts:dlnm.rr_axis"), grid: true },
      marks: [
        Plot.areaY(sorted, { x: "exposure", y1: "lo", y2: "hi", fill: "#1d9bf0", fillOpacity: 0.15 }),
        Plot.lineY(sorted, { x: "exposure", y: "rr", stroke: "#ff6b4a", strokeWidth: 2 }),
        Plot.ruleY([1], { stroke: "#555", strokeDasharray: "4,3" }),
        Plot.dot(markers, { x: "exposure", y: "rr", r: 3.5, fill: "#052e2b" }),
        Plot.tip(sorted, Plot.pointerX({ x: "exposure", y: "rr", title: (d) => `${d.exposure}°C — RR ${d.rr.toFixed(3)} [${d.lo.toFixed(3)}, ${d.hi.toFixed(3)}]` })),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [rows, t]);

  const hasAutocorr = rows.length > 0 && rows[0].has_autocorr;

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {ufLabel ? t("charts:dlnm.overall_title", { name: ufLabel }) : t("select_municipality")}
      </h3>
      {ufLabel && rows.length === 0 && <p className="page-lede">{t("charts:no_data")}</p>}
      <div
        ref={containerRef}
        role="img"
        aria-label={`${ufLabel ? t("charts:dlnm.overall_title", { name: ufLabel }) : t("select_municipality")} — ${t("charts:dlnm.exposure_axis")} x ${t("charts:dlnm.rr_axis")}`}
      />
      {ufLabel && rows.length > 0 && (
        <>
          {hasAutocorr && (
            <p className="badge badge-muted" style={{ marginTop: 8 }}>
              {t("charts:dlnm.autocorr_warning")}
            </p>
          )}
          <table className="visually-hidden">
            <caption>{t("charts:dlnm.overall_title", { name: ufLabel })}</caption>
            <thead>
              <tr>
                <th>{t("charts:dlnm.exposure_axis")}</th>
                <th>{t("charts:dlnm.rr_axis")}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <tr key={i}>
                  <td>{row.exposure}</td>
                  <td>{row.rr}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <ExportButtons
            rows={rows as unknown as Record<string, unknown>[]}
            getSvg={() => containerRef.current?.querySelector("svg") ?? null}
            baseFilename={`dlnm_overall_${ufLabel}`}
          />
          <InterpretGuide textKey="charts:interpret.dlnm_overall" />
        </>
      )}
    </div>
  );
}
