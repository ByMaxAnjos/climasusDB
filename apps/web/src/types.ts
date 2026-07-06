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

export type Metric = Extract<
  keyof HealthClimateRow,
  "deaths_total" | "tmax" | "precip"
>;

export const METRICS: { key: Metric; label: string }[] = [
  { key: "deaths_total", label: "Óbitos (grupos climate-sensitive)" },
  { key: "tmax", label: "Temperatura máxima (°C)" },
  { key: "precip", label: "Precipitação (mm)" },
];
