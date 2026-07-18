import { useTranslation } from "react-i18next";
import { Link } from "../../router";
import { DOC_PAGE_IDS, type DocPageId } from "./pages";

export function DocsPage({ page }: { page: string }) {
  const { t } = useTranslation("docs");

  if (!DOC_PAGE_IDS.includes(page as DocPageId)) {
    return (
      <div className="page">
        <p>
          <Link to="/docs">← {t("index_title")}</Link>
        </p>
        <p className="page-lede">{t("page_not_found")}</p>
      </div>
    );
  }

  const paragraphs = t(`page.${page}.body`, { returnObjects: true }) as string[];

  return (
    <div className="page" style={{ maxWidth: 720 }}>
      <p>
        <Link to="/docs">← {t("index_title")}</Link>
      </p>
      <h2 style={{ margin: "8px 0 16px 0" }}>{t(`page.${page}.title`)}</h2>
      {paragraphs.map((p, i) => (
        <p key={i} style={{ lineHeight: 1.6 }}>
          {p}
        </p>
      ))}
    </div>
  );
}
