import { useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useRoute } from "../../router";
import { FEATURED_THEMES } from "../../data/featured-themes";
import { getDatasetPresentation } from "../../data/dataset-meta";
import { CardMedia } from "../../components/CardMedia";
import { dataUrl } from "../../db";
import type { CatalogEntry, CatalogRoot } from "./types";

export function CatalogList() {
  const { t } = useTranslation("catalog");
  const { query: urlQuery } = useRoute();
  const tag = urlQuery.get("tag");
  const [datasets, setDatasets] = useState<CatalogEntry[] | null>(null);
  const [error, setError] = useState(false);
  const [search, setSearch] = useState("");

  useEffect(() => {
    // no-store: catalog.json muda a cada publicação — sem isso um cache
    // HTTP antigo pode servir uma lista de datasets desatualizada.
    fetch(dataUrl("/data/catalog.json"), { cache: "no-store" })
      .then((res) => res.json() as Promise<CatalogRoot>)
      .then((data) => setDatasets(data.datasets))
      .catch(() => setError(true));
  }, []);

  const theme = tag ? FEATURED_THEMES.find((th) => th.id === tag) : null;

  const visible = useMemo(() => {
    let list = theme ? datasets?.filter((d) => theme.datasets.includes(d.name)) : datasets;
    const term = search.trim().toLowerCase();
    if (term && list) {
      list = list.filter((d) => {
        const keywords = t(`dataset.${d.name}.keywords`, { returnObjects: true, defaultValue: [] }) as string[];
        const title = t(`dataset.${d.name}.title`, { defaultValue: d.name });
        const haystack = [d.name, title, ...keywords].join(" ").toLowerCase();
        return haystack.includes(term);
      });
    }
    return list;
  }, [datasets, theme, search, t]);

  return (
    <div className="page">
      <div className="eyebrow">{t("title")}</div>
      <h2 style={{ margin: "8px 0 16px 0" }}>{t("title")}</h2>
      <input
        className="search-input"
        type="search"
        placeholder={t("search_placeholder") ?? undefined}
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      {tag && (
        <p className="page-lede" style={{ marginTop: 12 }}>
          {t("filtered_by_tag", { tag })} — <Link to="/catalog">{t("clear_filter")}</Link>
        </p>
      )}
      {error && <p style={{ color: "var(--heat)", marginTop: 16 }}>{t("error")}</p>}
      {!datasets && !error && <p className="page-lede" style={{ marginTop: 16 }}>{t("loading")}</p>}
      {datasets && visible?.length === 0 && <p className="page-lede" style={{ marginTop: 16 }}>{t("no_results")}</p>}
      <div className="card-grid" style={{ marginTop: 20 }}>
        {visible?.map((d) => {
          const presentation = getDatasetPresentation(d.name);
          const keywords = t(`dataset.${d.name}.keywords`, { returnObjects: true, defaultValue: [] }) as string[];
          return (
            <Link key={d.name} to={`/catalog/${d.name}`} className="card card-media">
              <CardMedia
                icon={presentation.icon}
                gradient={presentation.gradient}
                title={t(`dataset.${d.name}.title`, { defaultValue: d.name })}
                description={t(`dataset.${d.name}.desc`, { defaultValue: "" })}
                footer={
                  <>
                    <p className="page-lede" style={{ margin: 0, fontSize: 12.5 }}>
                      {d.name} · {t("version")}: {d.latest} · {t("rows")}: {d.rows.toLocaleString()}
                    </p>
                    <div className="keyword-row">
                      <span className="badge badge-accent">Parquet</span>
                      {d.synthetic && <span className="badge badge-warning">{t("synthetic")}</span>}
                      {keywords.map((kw) => (
                        <span key={kw} className="badge badge-muted">
                          {kw}
                        </span>
                      ))}
                    </div>
                  </>
                }
              />
            </Link>
          );
        })}
      </div>
    </div>
  );
}
