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

// Rótulos vêm do i18n (chave metric.<key> em public/locales/*/common.json).
export const METRICS: { key: Metric }[] = [
  { key: "deaths_total" },
  { key: "tmax" },
  { key: "precip" },
];
