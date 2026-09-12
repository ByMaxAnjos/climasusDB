// Espelha o contrato de schema em docs/DATA_MODEL.md — grão município x dia.
export interface HealthClimateRow {
  code_muni: number;
  name_muni: string;
  date: string; // ISO YYYY-MM-DD
  deaths_total: number;
  deaths_resp: number;
  deaths_circ: number;
  tmean: number;
  tmax: number;
  tmin: number;
  precip: number;
  rh: number;
}

export type HealthMetric = Extract<
  keyof HealthClimateRow,
  "deaths_total" | "deaths_circ" | "precip"
>;

// "dlnm_rr" não é uma coluna de health_climate_daily — é grão UF (não
// município x dia), vindo de outros 3 datasets (ver DlnmExposureRow etc.
// abaixo). Explore.tsx/ChartPanel.tsx tratam esse indicador à parte dos
// demais (mapa: broadcast do valor da UF pros municípios; painel: gráficos
// DLNM dedicados, não os genéricos de série/comparação/sazonalidade).
export type Metric = HealthMetric | "dlnm_rr";

export function isDlnmMetric(metric: Metric): metric is "dlnm_rr" {
  return metric === "dlnm_rr";
}

// Rótulos vêm do i18n (chave metric.<key> em public/locales/*/common.json).
export const METRICS: { key: Metric }[] = [
  { key: "deaths_total" },
];

// Espelha docs/DATA_MODEL.md — health_climate_distributed_lag,
// dlnm_exposure_response, dlnm_lag_response, dlnm_surface (Fase 2b).
// disp_ratio/has_autocorr vêm duplicados como coluna de dado (não só em
// climasus_meta) porque o DuckDB-WASM não lê metadados de schema Arrow
// linha a linha — precisa ser um valor de dado pra virar aviso de UI.
export interface DlnmDiagnostics {
  uf: string;
  disp_ratio: number;
  has_autocorr: boolean;
}

export interface DlnmExposureRow extends DlnmDiagnostics {
  exposure: number;
  rr: number;
  lo: number;
  hi: number;
  pct: number | null; // não-nulo só nos pontos de grade mais próximos dos percentis reportados por sus_mod_dlnm()
}

export interface DlnmLagRow extends DlnmDiagnostics {
  lag: number;
  rr: number;
  lo: number;
  hi: number;
  rr_cum: number;
}

export interface DlnmSurfaceRow extends DlnmDiagnostics {
  exposure: number;
  lag: number;
  rr: number;
}
