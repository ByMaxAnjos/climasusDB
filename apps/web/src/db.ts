import * as duckdb from "@duckdb/duckdb-wasm";

// Singleton lazy: o motor só é instanciado quando a primeira query roda.
let dbPromise: Promise<duckdb.AsyncDuckDB> | null = null;

async function initDb(): Promise<duckdb.AsyncDuckDB> {
  // ponytail: bundles servidos via jsdelivr (quick-start oficial do duckdb-wasm)
  // em vez de empacotar os workers localmente com Vite — menos configuração
  // para o scaffold. Upgrade para bundle 100% local quando offline-first do
  // frontend for um requisito real (fase de deploy/GCP).
  const bundles = duckdb.getJsDelivrBundles();
  const bundle = await duckdb.selectBundle(bundles);
  const worker = await duckdb.createWorker(bundle.mainWorker!);
  const logger = new duckdb.ConsoleLogger(duckdb.LogLevel.WARNING);
  const db = new duckdb.AsyncDuckDB(logger, worker);
  await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
  return db;
}

async function getDb(): Promise<duckdb.AsyncDuckDB> {
  if (!dbPromise) {
    // Falhou (rede/CDN)? Limpa o memo para a próxima chamada tentar de novo,
    // em vez de cachear a promise rejeitada para sempre.
    dbPromise = initDb().catch((err) => {
      dbPromise = null;
      throw err;
    });
  }
  return dbPromise;
}

// Nomes virtuais usados nas queries SQL (registrados uma vez, via HTTP range
// requests). URL absoluta: o worker do DuckDB-WASM roda num contexto blob:
// sem base URL da página, então um caminho relativo ("/data/...") falha.
export const HEALTH_CLIMATE_FILE = "health_climate_daily.parquet";
export const DIM_STATION_FILE = "dim_station.parquet";
export const DLNM_EXPOSURE_FILE = "dlnm_exposure_response.parquet";
export const DLNM_LAG_FILE = "dlnm_lag_response.parquet";
export const DLNM_SURFACE_FILE = "dlnm_surface.parquet";

const registeredFiles = new Set<string>();

/** Registra um Parquet arbitrário como tabela virtual (idempotente). Usado
 * pelo Catálogo para consultar datasets fora do mapa fixo abaixo. */
export async function registerDataset(name: string, path: string): Promise<void> {
  if (registeredFiles.has(name)) return;
  const db = await getDb();
  await db.registerFileURL(name, new URL(path, window.location.origin).href, duckdb.DuckDBDataProtocol.HTTP, false);
  registeredFiles.add(name);
}

interface CatalogPartition {
  uf: string;
  path: string; // relativo a data/public
  rows: number;
}
interface CatalogDataset {
  name: string;
  latest: string;
  partitions: CatalogPartition[];
}
interface Catalog {
  datasets: CatalogDataset[];
}

// gold/{dataset} é particionado por UF (Fase 2: 27 UFs) — não há listagem de
// diretório em hosting estático/HTTP range (nem no bucket GCS futuro), então
// cada partição precisa da sua própria URL explícita. `catalog.json` já lista
// exatamente essas URLs (ver comentário em pipelines/R/catalog.R); a view
// nacional é a UNION de todas as partições da versão `latest`.
async function createUnionView(viewName: string, datasetName: string, catalog: Catalog, optional = false): Promise<boolean> {
  const ds = catalog.datasets.find((d) => d.name === datasetName);
  if (!ds) {
    if (optional) return false;
    throw new Error(`Dataset '${datasetName}' ausente em catalog.json`);
  }

  await Promise.all(
    ds.partitions.map((p, i) => registerDataset(`${datasetName}_${i}_${p.uf}.parquet`, `/data/${p.path}`)),
  );
  const fileList = ds.partitions.map((p, i) => `'${datasetName}_${i}_${p.uf}.parquet'`).join(", ");

  const db = await getDb();
  const conn = await db.connect();
  try {
    await conn.query(`CREATE OR REPLACE VIEW "${viewName}" AS SELECT * FROM read_parquet([${fileList}])`);
    return true;
  } finally {
    await conn.close();
  }
}

let datasetsReadyPromise: Promise<void> | null = null;
// Resolvido só depois de ensureDatasetsRegistered() rodar — os 3 datasets do
// indicador DLNM (Fase 2b) são opcionais (`make dlnm`/`run_dlnm.R` é um passo
// à parte de `run_national.R`), então o app não deve quebrar em quem ainda
// não rodou. Explore.tsx consulta isso pra decidir se mostra a opção.
let dlnmAvailable = false;

async function ensureDatasetsRegistered(): Promise<void> {
  if (!datasetsReadyPromise) {
    datasetsReadyPromise = (async () => {
      const res = await fetch(new URL("/data/catalog.json", window.location.origin).href);
      if (!res.ok) throw new Error(`catalog.json: HTTP ${res.status}`);
      const catalog: Catalog = await res.json();
      await createUnionView(HEALTH_CLIMATE_FILE, "health_climate_daily", catalog);
      await createUnionView(DIM_STATION_FILE, "dim_station", catalog);
      const [er, lr, sf] = await Promise.all([
        createUnionView(DLNM_EXPOSURE_FILE, "dlnm_exposure_response", catalog, true),
        createUnionView(DLNM_LAG_FILE, "dlnm_lag_response", catalog, true),
        createUnionView(DLNM_SURFACE_FILE, "dlnm_surface", catalog, true),
      ]);
      dlnmAvailable = er && lr && sf;
    })().catch((err) => {
      datasetsReadyPromise = null; // permite retry na próxima query
      throw err;
    });
  }
  await datasetsReadyPromise;
}

/** Indica se os 3 datasets DLNM (Fase 2b) existem no catálogo atual. Só é
 * confiável depois de pelo menos uma chamada a `query()`. */
export function isDlnmAvailable(): boolean {
  return dlnmAvailable;
}

/** Executa uma query SQL contra Parquet servido por HTTP e retorna linhas tipadas. */
export async function query<T = Record<string, unknown>>(sql: string): Promise<T[]> {
  await ensureDatasetsRegistered();
  const db = await getDb();
  const conn = await db.connect();
  try {
    const result = await conn.query(sql);
    return result.toArray().map((row) => row.toJSON() as T);
  } finally {
    await conn.close();
  }
}
