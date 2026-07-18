import { useTranslation } from "react-i18next";
import type { DlnmExposureRow, DlnmLagRow, DlnmSurfaceRow, HealthClimateRow, Metric } from "../../types";
import { isDlnmMetric } from "../../types";
import { TimeSeriesChart } from "./TimeSeriesChart";
import { ComparisonBarChart } from "./ComparisonBarChart";
import { SeasonalityChart, type SeasonalityRow } from "./SeasonalityChart";
import { DlnmOverallChart } from "./DlnmOverallChart";
import { DlnmLagChart } from "./DlnmLagChart";
import { DlnmSurfaceChart } from "./DlnmSurfaceChart";

export type ChartView = "timeseries" | "comparison" | "seasonality" | "dlnm_overall" | "dlnm_lag" | "dlnm_surface";
const HEALTH_VIEWS: ChartView[] = ["timeseries", "comparison", "seasonality"];
// O indicador DLNM tem grão UF (não município x dia) — não faz sentido nos
// 3 gráficos genéricos acima, então ganha seu próprio conjunto de abas,
// espelhando os 3 tipos de gráfico de climasus4r::plot_climate_health()
// (sus_mod_plot_dlnm.R): overall, lag, surface.
const DLNM_VIEWS: ChartView[] = ["dlnm_overall", "dlnm_lag", "dlnm_surface"];

interface ChartPanelProps {
  view: ChartView;
  onViewChange: (view: ChartView) => void;
  metric: Metric;
  muniLabel: string | null;
  seriesRows: HealthClimateRow[];
  seasonalityRows: SeasonalityRow[];
  comparisonValues: Record<number, number>;
  muniNames: Record<number, string>;
  scopeLabel: string;
  // DLNM (grão UF do município selecionado) — ver Explore.tsx
  dlnmUfLabel: string | null;
  dlnmExposureRows: DlnmExposureRow[];
  dlnmLagRows: DlnmLagRow[];
  dlnmSurfaceRows: DlnmSurfaceRow[];
}

export function ChartPanel({
  view,
  onViewChange,
  metric,
  muniLabel,
  seriesRows,
  seasonalityRows,
  comparisonValues,
  muniNames,
  scopeLabel,
  dlnmUfLabel,
  dlnmExposureRows,
  dlnmLagRows,
  dlnmSurfaceRows,
}: ChartPanelProps) {
  const { t } = useTranslation("charts");
  const views = isDlnmMetric(metric) ? DLNM_VIEWS : HEALTH_VIEWS;
  const activeView = views.includes(view) ? view : views[0];

  return (
    <div>
      <div style={{ display: "flex", gap: 6, marginBottom: 16, flexWrap: "wrap" }}>
        {views.map((v) => (
          <button
            key={v}
            className={`nav-link${activeView === v ? " active" : ""}`}
            style={{ border: "none", cursor: "pointer", background: activeView === v ? undefined : "transparent" }}
            onClick={() => onViewChange(v)}
          >
            {t(`tabs.${v}`)}
          </button>
        ))}
      </div>

      {activeView === "timeseries" && <TimeSeriesChart rows={seriesRows} metric={metric} muniLabel={muniLabel} />}
      {activeView === "comparison" && (
        <ComparisonBarChart values={comparisonValues} muniNames={muniNames} metric={metric} scopeLabel={scopeLabel} />
      )}
      {activeView === "seasonality" && <SeasonalityChart rows={seasonalityRows} metric={metric} muniLabel={muniLabel} />}
      {activeView === "dlnm_overall" && <DlnmOverallChart rows={dlnmExposureRows} ufLabel={dlnmUfLabel} />}
      {activeView === "dlnm_lag" && <DlnmLagChart rows={dlnmLagRows} ufLabel={dlnmUfLabel} />}
      {activeView === "dlnm_surface" && <DlnmSurfaceChart rows={dlnmSurfaceRows} ufLabel={dlnmUfLabel} />}
    </div>
  );
}
