import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link } from "../../router";
import { dataUrl, query, registerDataset } from "../../db";
import type { CatalogEntry, CatalogRoot, DataPackage } from "./types";

interface CoverageRow {
  min_x: string | number | null;
  max_x: string | number | null;
  min_y: number | null;
  max_y: number | null;
}

// `from` é uma expressão FROM completa (ex. read_parquet([...]) sobre todas
// as partições por UF) — a cobertura é do dataset nacional, não de uma UF só.
function coverageSql(from: string, fieldNames: string[]): string | null {
  if (fieldNames.includes("date")) {
    return `SELECT strftime(min(date), '%Y-%m-%d') AS min_x, strftime(max(date), '%Y-%m-%d') AS max_x, NULL AS min_y, NULL AS max_y FROM ${from}`;
  }
  if (fieldNames.includes("start_date")) {
    return `SELECT strftime(min(start_date), '%Y-%m-%d') AS min_x, strftime(max(end_date), '%Y-%m-%d') AS max_x, NULL AS min_y, NULL AS max_y FROM ${from}`;
  }
  if (fieldNames.includes("latitude") && fieldNames.includes("longitude")) {
    return `SELECT min(longitude) AS min_x, max(longitude) AS max_x, min(latitude) AS min_y, max(latitude) AS max_y FROM ${from}`;
  }
  return null;
}

export function CatalogDetail({ dataset }: { dataset: string }) {
  const { t } = useTranslation("catalog");
  const [entry, setEntry] = useState<CatalogEntry | null>(null);
  const [pkg, setPkg] = useState<DataPackage | null>(null);
  const [coverage, setCoverage] = useState<CoverageRow | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    setEntry(null);
    setPkg(null);
    setCoverage(null);
    setError(false);

    (async () => {
      try {
        const catalog = (await (await fetch(dataUrl("/data/catalog.json"))).json()) as CatalogRoot;
        const found = catalog.datasets.find((d) => d.name === dataset);
        if (!found) {
          setError(true);
          return;
        }
        setEntry(found);

        const dpPath = found.path.replace(/data\.parquet$/, "datapackage.json");
        const dp = (await (await fetch(dataUrl(`/data/${dpPath}`))).json()) as DataPackage;
        setPkg(dp);

        const fields = dp.resources[0]?.schema.fields.map((f) => f.name) ?? [];
        const partitions = found.partitions?.length ? found.partitions : [{ uf: "", path: found.path, rows: found.rows }];
        const tables = partitions.map((_, i) => `${dataset}_detail_${i}.parquet`);
        const sql = coverageSql(`read_parquet([${tables.map((f) => `'${f}'`).join(", ")}])`, fields);
        if (sql) {
          await Promise.all(partitions.map((p, i) => registerDataset(tables[i], `/data/${p.path}`)));
          const rows = await query<CoverageRow>(sql);
          setCoverage(rows[0] ?? null);
        }
      } catch {
        setError(true);
      }
    })();
  }, [dataset]);

  if (error) return <p className="page" style={{ color: "var(--heat)" }}>{t("error")}</p>;
  if (!entry || !pkg) return <p className="page page-lede">{t("loading")}</p>;

  const resourceFormats = Array.from(new Set(pkg.resources.map((r) => r.format)));
  const hasCsv = resourceFormats.includes("csv");

  const toVariantPath = (path: string, suffix: string) => path.replace(/data\.parquet$/, `data${suffix}`);

  return (
    <div className="page">
      <p>
        <Link to="/catalog">← {t("title")}</Link>
      </p>
      <h2>{pkg.title ?? pkg.name}</h2>
      <p className="page-lede" style={{ fontSize: 13, color: "var(--muted)" }}>{pkg.name}</p>
      <p className="page-lede">{pkg.description}</p>
      <p className="page-lede">
        {t("version")}: {pkg.version} · {t("rows")}: {pkg.rows.toLocaleString()}
      </p>
      {entry.partitions?.length > 1 ? (
        // Dataset particionado por UF: um botão por UF para Parquet, e um
        // segundo bloco para formatos de conveniência quando existirem.
        <section>
          <div className="eyebrow">{t("download_parquet")}</div>
          <p style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 8 }}>
            {entry.partitions.map((p) => (
              <a key={p.path} className="btn" href={dataUrl(`/data/${p.path}`)} download>
                {p.uf || entry.name}
              </a>
            ))}
          </p>
          {hasCsv && (
            <>
              <div className="eyebrow" style={{ marginTop: 18 }}>{t("download_csv")}</div>
              <p style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 8 }}>
                {entry.partitions.map((p) => (
                  <a key={`${p.path}-csv`} className="btn" href={dataUrl(`/data/${toVariantPath(p.path, ".csv.zip")}`)} download>
                    {p.uf || entry.name}
                  </a>
                ))}
              </p>
            </>
          )}
        </section>
      ) : (
        <p style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
          <a className="btn btn-primary" href={dataUrl(`/data/${entry.path}`)} download>
            Parquet
          </a>
          {hasCsv && (
            <a className="btn" href={dataUrl(`/data/${toVariantPath(entry.path, ".csv.zip")}`)} download>
              CSV
            </a>
          )}
        </p>
      )}
      {pkg.licenses.map((lic) => (
        <p key={lic.name} className="page-lede">
          {t("license")}:{" "}
          <a href={lic.path} target="_blank" rel="noreferrer">
            {lic.name}
          </a>
        </p>
      ))}

      {coverage && (
        <section style={{ marginTop: 28 }}>
          <div className="eyebrow">{t("coverage")}</div>
          <p style={{ margin: "6px 0 0 0" }}>
            {String(coverage.min_x)} – {String(coverage.max_x)}
            {coverage.min_y != null && ` · lat/lon ${coverage.min_y.toFixed(2)}–${coverage.max_y?.toFixed(2)}`}
          </p>
        </section>
      )}

      <section style={{ marginTop: 28 }}>
        <div className="eyebrow">{t("schema")}</div>
        {hasCsv && (
          <p className="page-lede" style={{ marginTop: 8, fontSize: 13, color: "var(--muted)" }}>
            Parquet sempre disponível · formatos de conveniência podem variar por dataset
          </p>
        )}
        <table className="data-table" style={{ marginTop: 10 }}>
          <thead>
            <tr>
              <th>{t("column")}</th>
              <th>{t("type")}</th>
              <th>{t("description")}</th>
            </tr>
          </thead>
          <tbody>
            {pkg.resources[0]?.schema.fields.map((f) => (
              <tr key={f.name}>
                <td>
                  <code>{f.name}</code>
                </td>
                <td style={{ color: "var(--muted)" }}>{f.type}</td>
                <td style={{ color: "var(--muted)" }}>{f.description || "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section style={{ marginTop: 28 }}>
        <div className="eyebrow">{t("pipeline_code")}</div>
        <p className="page-lede" style={{ margin: "6px 0 0 0", fontSize: 12.5 }}>R</p>
        {pkg.generator?.r?.snippet ? (
          <>
            <p style={{ margin: "2px 0 0 0", color: "var(--muted)", fontSize: 13 }}>
              {pkg.generator.r.path}
              {pkg.generator.r.fn ? ` :: ${pkg.generator.r.fn}` : ""}
            </p>
            <pre className="code-block" style={{ marginTop: 8 }}>
              {pkg.generator.r.snippet}
            </pre>
          </>
        ) : (
          <p style={{ margin: "2px 0 0 0", color: "var(--muted)" }}>{t("code_not_available")}</p>
        )}

        <p className="page-lede" style={{ margin: "18px 0 0 0", fontSize: 12.5 }}>Python</p>
        {pkg.generator?.python?.snippet ? (
          <>
            <p style={{ margin: "2px 0 0 0", color: "var(--muted)", fontSize: 13 }}>
              {pkg.generator.python.path}
              {pkg.generator.python.fn ? ` :: ${pkg.generator.python.fn}` : ""}
            </p>
            <pre className="code-block" style={{ marginTop: 8 }}>
              {pkg.generator.python.snippet}
            </pre>
          </>
        ) : (
          <p style={{ margin: "2px 0 0 0", color: "var(--muted)" }}>{t("code_not_available")}</p>
        )}
      </section>

      <section style={{ marginTop: 28 }}>
        <div className="eyebrow">{t("provenance")}</div>
        <pre className="code-block" style={{ marginTop: 10 }}>
          {JSON.stringify(pkg.climasus_meta, null, 2)}
        </pre>
      </section>
    </div>
  );
}
