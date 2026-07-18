import { useTranslation } from "react-i18next";

export function InterpretGuide({ textKey }: { textKey: string }) {
  const { t } = useTranslation("charts");

  return (
    <details style={{ marginTop: 12 }}>
      <summary
        style={{
          cursor: "pointer",
          fontFamily: '"IBM Plex Mono", monospace',
          fontSize: 12,
          letterSpacing: "0.1em",
          textTransform: "uppercase",
          color: "var(--accent)",
        }}
      >
        {t("how_to_interpret")}
      </summary>
      <p className="page-lede" style={{ marginTop: 8, fontSize: 13.5 }}>
        {t(textKey)}
      </p>
    </details>
  );
}
