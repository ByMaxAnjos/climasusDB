// Agrupamentos de estados alternativos ao filtro oficial de Região (IBGE).
// Não são polígonos próprios — são a união das geometrias dos estados
// listados em abbrev_state, calculada em tempo real a partir de
// estados_br.geojson (ver Map.tsx). Categorias são independentes entre si;
// um estado pode aparecer em várias (ex. MG está em cerrado, caatinga,
// semi_arido, mata_atlantica e sudene).
export type GroupCategory = "biomes" | "hydro_climate" | "health_agri_geo";

export interface StateGroup {
  id: string;
  category: GroupCategory;
  ufs: string[];
}

export const STATE_GROUPS: StateGroup[] = [
  // ---- Biomas ----
  { id: "amazonia_legal", category: "biomes", ufs: ["AC", "AP", "AM", "PA", "RO", "RR", "MT", "MA", "TO"] },
  {
    id: "mata_atlantica",
    category: "biomes",
    ufs: ["AL", "BA", "CE", "ES", "GO", "MA", "MG", "MS", "PB", "PE", "PI", "PR", "RJ", "RN", "RS", "SC", "SE", "SP"],
  },
  { id: "caatinga", category: "biomes", ufs: ["AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE", "MG"] },
  { id: "cerrado", category: "biomes", ufs: ["BA", "DF", "GO", "MA", "MG", "MS", "MT", "PA", "PI", "PR", "RO", "SP", "TO"] },
  { id: "pantanal", category: "biomes", ufs: ["MT", "MS"] },
  { id: "pampa", category: "biomes", ufs: ["RS"] },

  // ---- Hidrografia e clima ----
  { id: "bacia_amazonia", category: "hydro_climate", ufs: ["AC", "AM", "AP", "MT", "PA", "RO", "RR"] },
  { id: "bacia_sao_francisco", category: "hydro_climate", ufs: ["AL", "BA", "DF", "GO", "MG", "PE", "SE"] },
  { id: "bacia_parana", category: "hydro_climate", ufs: ["GO", "MG", "MS", "PR", "SP"] },
  { id: "bacia_tocantins", category: "hydro_climate", ufs: ["GO", "MA", "PA", "TO"] },
  { id: "semi_arido", category: "hydro_climate", ufs: ["AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE", "MG"] },

  // ---- Saúde, agricultura e geopolítica ----
  { id: "matopiba", category: "health_agri_geo", ufs: ["MA", "TO", "PI", "BA"] },
  { id: "arco_desmatamento", category: "health_agri_geo", ufs: ["RO", "AC", "AM", "PA", "MT", "MA"] },
  { id: "dengue_hyperendemic", category: "health_agri_geo", ufs: ["GO", "MS", "MT", "PR", "RJ", "SP"] },
  { id: "sudene", category: "health_agri_geo", ufs: ["AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE", "MG", "ES"] },
  {
    id: "fronteira_brasil",
    category: "health_agri_geo",
    ufs: ["AC", "AM", "AP", "MT", "MS", "PA", "PR", "RO", "RR", "RS", "SC"],
  },
];

export const GROUP_CATEGORIES: GroupCategory[] = ["biomes", "hydro_climate", "health_agri_geo"];

export function getStateGroup(id: string | null): StateGroup | null {
  if (!id) return null;
  return STATE_GROUPS.find((g) => g.id === id) ?? null;
}
