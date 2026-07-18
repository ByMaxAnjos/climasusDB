import { useTranslation } from "react-i18next";
import { Link } from "../../router";
import { getTheme } from "../../data/featured-themes";
import { Explore } from "../Explore";

export function ThemeApp({ themeId }: { themeId: string }) {
  const { t } = useTranslation(["docs", "featured"]);
  const theme = getTheme(themeId);

  if (!theme || theme.status !== "available") {
    return (
      <div className="page">
        <p>
          <Link to="/apps">← {t("docs:apps_title")}</Link>
        </p>
        <p className="page-lede">{t("docs:app_unavailable")}</p>
      </div>
    );
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", flex: 1, minHeight: 0 }}>
      <div style={{ padding: "16px 24px", borderBottom: "1px solid var(--rule)", background: "var(--paper-3)" }}>
        <p style={{ margin: 0 }}>
          <Link to="/apps">← {t("docs:apps_title")}</Link>
        </p>
        <h2 style={{ margin: "8px 0 4px 0" }}>{t(`featured:${theme.titleKey.replace("featured.", "")}`)}</h2>
        <p className="page-lede" style={{ margin: 0 }}>
          {t(`featured:${theme.descKey.replace("featured.", "")}`)}
        </p>
        {theme.docPage && (
          <p style={{ margin: "6px 0 0 0" }}>
            <Link to={`/docs/${theme.docPage}`}>{t("docs:read_case_study")}</Link>
          </p>
        )}
      </div>
      <Explore forcedThemeId={theme.id} />
    </div>
  );
}
