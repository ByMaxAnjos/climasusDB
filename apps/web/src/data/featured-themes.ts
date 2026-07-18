import type { IconKey } from "../components/Icon";
import type { Metric } from "../types";

// Taxonomia curada à mão a partir dos temas dos tutoriais/estudos de caso do
// climasus4r (vignettes-pt) — não é derivada de climasus_meta, que não tem
// campo de tema. `status` decide badge/clicabilidade em Catalog e Apps; trocar
// para "available" quando o dataset correspondente for publicado.
export interface FeaturedTheme {
  id: string;
  status: "available" | "coming_soon";
  datasets: string[];
  explorePreset: { metric: Metric };
  titleKey: string;
  descKey: string;
  keywordsKey: string;
  docPage: string | null;
  icon: IconKey;
  gradient: string;
}

export const FEATURED_THEMES: FeaturedTheme[] = [
  {
    id: "heat-cardio",
    status: "available",
    datasets: ["heatwave_events", "health_climate_daily"],
    explorePreset: { metric: "deaths_total" },
    titleKey: "featured.heat_cardio.title",
    descKey: "featured.heat_cardio.desc",
    keywordsKey: "featured.heat_cardio.keywords",
    docPage: "heat-cardio",
    icon: "heart",
    gradient: "linear-gradient(135deg, var(--heat), var(--health))",
  },
  {
    id: "cold-resp",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "deaths_total" },
    titleKey: "featured.cold_resp.title",
    descKey: "featured.cold_resp.desc",
    keywordsKey: "featured.cold_resp.keywords",
    docPage: null,
    icon: "snowflake",
    gradient: "linear-gradient(135deg, var(--climate), var(--climate-2))",
  },
  {
    id: "vector-borne",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "deaths_total" },
    titleKey: "featured.vector_borne.title",
    descKey: "featured.vector_borne.desc",
    keywordsKey: "featured.vector_borne.keywords",
    docPage: null,
    icon: "bug",
    gradient: "linear-gradient(135deg, var(--air), var(--health))",
  },
  {
    id: "resp-air-quality",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "deaths_total" },
    titleKey: "featured.resp_air_quality.title",
    descKey: "featured.resp_air_quality.desc",
    keywordsKey: "featured.resp_air_quality.keywords",
    docPage: null,
    icon: "wind",
    gradient: "linear-gradient(135deg, var(--climate-2), var(--air))",
  },
  {
    id: "bioclimatic-indices",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "tmax" },
    titleKey: "featured.bioclimatic_indices.title",
    descKey: "featured.bioclimatic_indices.desc",
    keywordsKey: "featured.bioclimatic_indices.keywords",
    docPage: null,
    icon: "gauge",
    gradient: "linear-gradient(135deg, var(--drought), var(--drought-2))",
  },
  {
    id: "climate-health-integration",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "tmax" },
    titleKey: "featured.climate_health_integration.title",
    descKey: "featured.climate_health_integration.desc",
    keywordsKey: "featured.climate_health_integration.keywords",
    docPage: null,
    icon: "link",
    gradient: "linear-gradient(135deg, var(--health), var(--climate))",
  },
  {
    id: "vulnerability",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "deaths_total" },
    titleKey: "featured.vulnerability.title",
    descKey: "featured.vulnerability.desc",
    keywordsKey: "featured.vulnerability.keywords",
    docPage: null,
    icon: "shield",
    gradient: "linear-gradient(135deg, var(--ink-3), var(--health))",
  },
  {
    id: "waterborne",
    status: "coming_soon",
    datasets: [],
    explorePreset: { metric: "deaths_total" },
    titleKey: "featured.waterborne.title",
    descKey: "featured.waterborne.desc",
    keywordsKey: "featured.waterborne.keywords",
    docPage: null,
    icon: "droplet",
    gradient: "linear-gradient(135deg, var(--climate), var(--air-2))",
  },
];

export function getTheme(id: string | null): FeaturedTheme | null {
  if (!id) return null;
  return FEATURED_THEMES.find((theme) => theme.id === id) ?? null;
}
