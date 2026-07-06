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
  if (!dbPromise) dbPromise = initDb();
  return dbPromise;
}

/** Nome virtual usado nas queries SQL (registrado uma vez, via HTTP range requests). */
export const HEALTH_CLIMATE_FILE = "health_climate_daily.parquet";
// URL absoluta: o worker do DuckDB-WASM roda num contexto blob: sem base URL da
// página, então um caminho relativo ("/data/...") falha ao montar a request.
const HEALTH_CLIMATE_PARQUET_URL = new URL(
  "/data/gold/health_climate_daily/v0.1.0/uf=RO/data.parquet",
  window.location.origin,
).href;

let registered = false;
async function ensureDatasetsRegistered(): Promise<void> {
  if (registered) return;
  const db = await getDb();
  await db.registerFileURL(
    HEALTH_CLIMATE_FILE,
    HEALTH_CLIMATE_PARQUET_URL,
    duckdb.DuckDBDataProtocol.HTTP,
    false,
  );
  registered = true;
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
