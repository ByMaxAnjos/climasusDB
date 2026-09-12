import { useTranslation } from "react-i18next";
import { THIRD_PARTY_APPS } from "../../data/third-party-apps";
import { CardMedia } from "../../components/CardMedia";

export function AppsGallery() {
  const { t } = useTranslation("docs");

  return (
    <div className="page">
      <div className="eyebrow">{t("apps_title")}</div>
      <h2 style={{ margin: "8px 0 12px 0" }}>{t("apps_title")}</h2>
      <p className="page-lede" style={{ maxWidth: 780 }}>{t("apps_lede")}</p>

      {THIRD_PARTY_APPS.length === 0 ? (
        <section style={{ marginTop: 24 }}>
          <h3 style={{ margin: "0 0 8px 0" }}>{t("apps_empty_title")}</h3>
          <p className="page-lede" style={{ maxWidth: 720 }}>{t("apps_empty_body")}</p>
          <p style={{ marginTop: 14 }}>
            <a className="btn btn-primary" href="mailto:max.anjos@campus.ul.pt">
              {t("apps_share_label")}
            </a>
          </p>
        </section>
      ) : (
        <div className="card-grid" style={{ marginTop: 24 }}>
          {THIRD_PARTY_APPS.map((app) => {
            const external = /^https?:\/\//.test(app.url);
            return (
              <a
                key={`${app.organization}-${app.name}`}
                href={app.url}
                className="card card-media"
                target={external ? "_blank" : undefined}
                rel={external ? "noreferrer" : undefined}
              >
                <CardMedia
                  icon="link"
                  gradient="linear-gradient(135deg, var(--health), var(--climate))"
                  title={app.name}
                  description={`${app.organization} · ${app.description}`}
                  footer={
                    <div className="keyword-row">
                      <span className="badge badge-accent">{t(`apps_status.${app.status}`)}</span>
                      {app.datasets.map((dataset) => (
                        <span key={dataset} className="badge badge-muted">
                          {dataset}
                        </span>
                      ))}
                    </div>
                  }
                />
              </a>
            );
          })}
        </div>
      )}
    </div>
  );
}
