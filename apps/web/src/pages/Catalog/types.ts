export interface CatalogPartition {
  uf: string;
  path: string; // relativo a /data
  rows: number;
}

export interface CatalogEntry {
  name: string;
  latest: string;
  versions: string | string[];
  synthetic: boolean;
  path: string; // primeira partição (relativo a /data) — usar `partitions` para o dataset completo
  rows: number; // total do dataset (todas as partições)
  partitions: CatalogPartition[];
}

export interface CatalogRoot {
  datasets: CatalogEntry[];
}

export interface DataPackageField {
  name: string;
  type: string;
  description?: string;
}

// `available: false` = linguagem reservada mas sem pipeline ainda (ex. Python);
// caso contrário path/fn/snippet descrevem o trecho de código que gera o dado.
export interface GeneratorCode {
  available?: false;
  path?: string;
  fn?: string;
  snippet?: string;
}

export interface DatasetGenerator {
  r?: GeneratorCode;
  python?: GeneratorCode;
}

export interface DataPackage {
  name: string;
  title?: string;
  version: string;
  description: string;
  licenses: { name: string; path: string }[];
  resources: { name: string; path: string; format: string; schema: { fields: DataPackageField[] } }[];
  generator?: DatasetGenerator;
  climasus_meta: Record<string, unknown>;
  rows: number;
}
