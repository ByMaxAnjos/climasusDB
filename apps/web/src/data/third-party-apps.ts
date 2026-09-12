export type ThirdPartyAppStatus = "active" | "inactive" | "prospecting" | "example";

export interface ThirdPartyApp {
  name: string;
  organization: string;
  description: string;
  datasets: string[];
  url: string;
  status: ThirdPartyAppStatus;
}

// Vitrine curada de parceiros e organizações externas que usam dados do
// climasusDB. A primeira entrada é demonstrativa, para mostrar o tipo de
// aplicação possível enquanto usos externos reais ainda são cadastrados.
export const THIRD_PARTY_APPS: ThirdPartyApp[] = [
  {
    name: "Dashboard demonstrativo clima-saúde",
    organization: "climasusDB",
    description: "Painel com grupos de óbitos sensíveis ao clima, série mensal e associação exploratória com temperatura e precipitação.",
    datasets: ["health_climate_daily", "dim_station"],
    url: "/#/apps/deaths-dashboard",
    status: "example",
  },
];
