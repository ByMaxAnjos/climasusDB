import { useTranslation } from "react-i18next";
import { Link } from "../../router";
import { FEATURED_THEMES } from "../../data/featured-themes";
import { CardMedia } from "../../components/CardMedia";

export function AppsGallery() {
  const { t } = useTranslation(["docs", "featured"]);

  return (
    <div className="page">
      <div className="eyebrow">{t("docs:apps_title")}</div>
      <h2 style={{ margin: "8px 0 24px 0" }}>{t("docs:apps_title")}</h2>
      <div className="card-grid">
        {FEATURED_THEMES.map((theme) => {
          const available = theme.status === "available";
          const ns = (key: string) => key.replace("featured.", "featured:");
          const keywords = t(ns(theme.keywordsKey), { returnObjects: true, defaultValue: [] }) as string[];
          const media = (
            <CardMedia
              icon={theme.icon}
              gradient={theme.gradient}
              title={t(ns(theme.titleKey))}
              description={t(ns(theme.descKey))}
              footer={
                <div className="keyword-row">
                  {!available && <span className="badge badge-warning">{t("docs:coming_soon")}</span>}
                  {keywords.map((kw) => (
                    <span key={kw} className="badge badge-muted">
                      {kw}
                    </span>
                  ))}
                </div>
              }
            />
          );
          return available ? (
            <Link key={theme.id} to={`/apps/${theme.id}`} className="card card-media">
              {media}
            </Link>
          ) : (
            <div key={theme.id} className="card card-media disabled">
              {media}
            </div>
          );
        })}
      </div>
    </div>
  );
}
