import type { IconKey } from "../components/Icon";

// Apresentação curada por dataset do catalog.json — ícone/gradiente do card.
// Título/descrição/palavras-chave vêm do i18n (namespace catalog, chave
// dataset.<name>.*) para acompanhar pt/en/es.
export interface DatasetPresentation {
  name: string;
  icon: IconKey;
  gradient: string;
}

export const DATASET_PRESENTATION: DatasetPresentation[] = [
  { name: "dim_station", icon: "antenna", gradient: "linear-gradient(135deg, var(--climate), var(--health))" },
  { name: "health_climate_daily", icon: "bar-chart", gradient: "linear-gradient(135deg, var(--heat), var(--health))" },
  { name: "heatwave_events", icon: "flame", gradient: "linear-gradient(135deg, var(--heat), var(--drought))" },
  { name: "health_climate_distributed_lag", icon: "link", gradient: "linear-gradient(135deg, var(--health), var(--climate))" },
  { name: "dlnm_exposure_response", icon: "gauge", gradient: "linear-gradient(135deg, var(--heat), var(--climate))" },
  { name: "dlnm_lag_response", icon: "gauge", gradient: "linear-gradient(135deg, var(--heat), var(--health))" },
  { name: "dlnm_surface", icon: "gauge", gradient: "linear-gradient(135deg, var(--heat-2), var(--heat))" },
  { name: "env_era5_daily", icon: "wind", gradient: "linear-gradient(135deg, var(--climate), var(--climate-2))" },
  { name: "env_chirps_daily", icon: "droplet", gradient: "linear-gradient(135deg, var(--climate-2), var(--health))" },
  { name: "env_prodes_daily", icon: "flame", gradient: "linear-gradient(135deg, var(--drought), var(--heat))" },
  { name: "env_pollution_cams_daily", icon: "shield", gradient: "linear-gradient(135deg, var(--air), var(--air-2))" },
];

const FALLBACK: DatasetPresentation = {
  name: "",
  icon: "bar-chart",
  gradient: "linear-gradient(135deg, var(--ink-3), var(--health))",
};

export function getDatasetPresentation(name: string): DatasetPresentation {
  return DATASET_PRESENTATION.find((d) => d.name === name) ?? FALLBACK;
}
