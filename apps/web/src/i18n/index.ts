import i18next from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import HttpBackend from "i18next-http-backend";

i18next
  .use(HttpBackend)
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: "pt",
    supportedLngs: ["pt", "en", "es"],
    ns: ["common", "catalog", "docs", "featured", "charts", "groups"],
    defaultNS: "common",
    backend: { loadPath: "/locales/{{lng}}/{{ns}}.json" },
    interpolation: { escapeValue: false },
  });

// Mantém <html lang> sincronizado com o idioma ativo (leitores de tela).
i18next.on("languageChanged", (lng) => {
  document.documentElement.lang = lng;
});

export default i18next;
