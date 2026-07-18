import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import * as Plot from "@observablehq/plot";
import type { DlnmSurfaceRow } from "../../types";
import { ExportButtons } from "./ExportButtons";
import { InterpretGuide } from "./InterpretGuide";

interface DlnmSurfaceChartProps {
  rows: DlnmSurfaceRow[]; // 1 UF, grão exposição x lag (~100 x 22 pontos) — ver docs/DATA_MODEL.md
  ufLabel: string | null;
}

// Espelha climasus4r:::.plot_dlnm_surface()/.plot_dlnm_contour(): heatmap de
// log(RR) por exposição (eixo Y) x lag (eixo X) — escala divergente
// centrada em RR=1 (log(RR)=0), pra calor/frio ficarem visualmente opostos.
export function DlnmSurfaceChart({ rows, ufLabel }: DlnmSurfaceChartProps) {
  const { t } = useTranslation(["common", "charts"]);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    container.innerHTML = "";
    if (rows.length === 0) return;

    // A grade publicada tem ~100 valores de exposição distintos por UF — como
    // categorias num Plot.cell isso amontoa 100 rótulos no eixo Y (e
    // Plot.raster, que trataria os eixos como contínuos, não renderizou a
    // imagem de forma confiável). Agrupar em bins de 1°C dá um eixo legível
    // (~15-20 categorias) sem precisar de outro tipo de mark.
    const binned = new Map<string, { lag: number; exposure: number; sum: number; count: number }>();
    for (const r of rows) {
      const exposure = Math.round(r.exposure);
      const key = `${r.lag}|${exposure}`;
      const entry = binned.get(key) ?? { lag: r.lag, exposure, sum: 0, count: 0 };
      entry.sum += Math.log(r.rr);
      entry.count += 1;
      binned.set(key, entry);
    }
    const data = Array.from(binned.values()).map((e) => ({
      lag: e.lag,
      exposure: e.exposure,
      log_rr: e.sum / e.count,
    }));
    const maxAbs = Math.max(...data.map((d) => Math.abs(d.log_rr)), 1e-6);

    const plot = Plot.plot({
      width: container.clientWidth || 640,
      height: 300,
      marginLeft: 50,
      x: { label: t("charts:dlnm.lag_axis") },
      y: { label: t("charts:dlnm.exposure_axis") },
      color: {
        type: "linear",
        domain: [-maxAbs, maxAbs],
        range: ["#1d9bf0", "#f5f5f0", "#ff6b4a"],
        label: t("charts:dlnm.log_rr_axis"),
        legend: true,
      },
      marks: [
        Plot.cell(data, { x: "lag", y: "exposure", fill: "log_rr" }),
        Plot.tip(
          data,
          Plot.pointer({ x: "lag", y: "exposure", title: (d) => `lag ${d.lag}d, ${d.exposure}°C — log(RR) ${d.log_rr.toFixed(3)}` }),
        ),
      ],
    });

    container.appendChild(plot);
    return () => plot.remove();
  }, [rows, t]);

  const hasAutocorr = rows.length > 0 && rows[0].has_autocorr;

  return (
    <div>
      <h3 style={{ margin: "0 0 8px 0", fontSize: 14 }}>
        {ufLabel ? t("charts:dlnm.surface_title", { name: ufLabel }) : t("select_municipality")}
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
            baseFilename={`dlnm_surface_${ufLabel}`}
          />
          <InterpretGuide textKey="charts:interpret.dlnm_surface" />
        </>
      )}
    </div>
  );
}
