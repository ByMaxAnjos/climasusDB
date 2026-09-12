import { useTranslation } from "react-i18next";
import { Link, useRoute } from "./router";
import { Explore } from "./pages/Explore";
import { CatalogList } from "./pages/Catalog/CatalogList";
import { CatalogDetail } from "./pages/Catalog/CatalogDetail";
import { AppsGallery } from "./pages/Apps/AppsGallery";
import { DeathsDashboard } from "./pages/Apps/DeathsDashboard";
import { ThemeApp } from "./pages/Apps/ThemeApp";
import { DocsIndex } from "./pages/Docs/DocsIndex";
import { DocsPage } from "./pages/Docs/DocsPage";

const NAV_ITEMS = [
  { path: "explore", labelKey: "nav.explore" },
  { path: "catalog", labelKey: "nav.catalog" },
  { path: "apps", labelKey: "nav.apps" },
  { path: "docs", labelKey: "nav.docs" },
] as const;

function renderPage(path: string, param: string | null) {
  switch (path) {
    case "catalog":
      return param ? <CatalogDetail dataset={param} /> : <CatalogList />;
    case "apps":
      if (param === "deaths-dashboard") return <DeathsDashboard />;
      return param ? <ThemeApp themeId={param} /> : <AppsGallery />;
    case "docs":
      return param ? <DocsPage page={param} /> : <DocsIndex />;
    case "explore":
    default:
      return <Explore />;
  }
}

export function App() {
  const { t } = useTranslation();
  const { path, param } = useRoute();

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100vh" }}>
      <header className="app-nav">
        <span className="brand">
          climasus<span className="accent">DB</span>
        </span>
        <nav className="nav-links">
          {NAV_ITEMS.map((item) => (
            <Link key={item.path} to={item.path} className={`nav-link${path === item.path ? " active" : ""}`}>
              {t(item.labelKey)}
            </Link>
          ))}
        </nav>
      </header>
      {renderPage(path, param)}
    </div>
  );
}
