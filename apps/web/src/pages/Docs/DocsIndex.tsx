import { useTranslation } from "react-i18next";
import { Link } from "../../router";
import { DOC_PAGE_IDS } from "./pages";

export function DocsIndex() {
  const { t } = useTranslation("docs");

  return (
    <div className="page">
      <div className="eyebrow">{t("index_title")}</div>
      <h2 style={{ margin: "8px 0 16px 0" }}>{t("index_title")}</h2>
      <p className="page-lede">
        {t("pipeline_link_intro")}{" "}
        <a href="https://bymaxanjos.github.io/climasus4r/" target="_blank" rel="noreferrer">
          {t("pipeline_link_label")}
        </a>
      </p>
      <div className="card-grid" style={{ marginTop: 20 }}>
        {DOC_PAGE_IDS.map((id) => (
          <Link key={id} to={`/docs/${id}`} className="card">
            <h3 style={{ margin: 0, fontSize: 20 }}>{t(`page.${id}.title`)}</h3>
          </Link>
        ))}
      </div>
    </div>
  );
}
