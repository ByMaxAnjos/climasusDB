import { useTranslation } from "react-i18next";
import { downloadCsv, downloadSvgAsPng, downloadXlsx } from "./export";

interface ExportButtonsProps {
  rows: Record<string, unknown>[];
  getSvg?: () => SVGSVGElement | null;
  baseFilename: string;
}

export function ExportButtons({ rows, getSvg, baseFilename }: ExportButtonsProps) {
  const { t } = useTranslation("charts");

  return (
    <div style={{ display: "flex", gap: 8, marginTop: 10, flexWrap: "wrap" }}>
      <button className="btn btn-ghost" style={{ padding: "5px 14px", fontSize: 12 }} onClick={() => downloadCsv(rows, `${baseFilename}.csv`)}>
        {t("export.csv")}
      </button>
      <button className="btn btn-ghost" style={{ padding: "5px 14px", fontSize: 12 }} onClick={() => downloadXlsx(rows, `${baseFilename}.xlsx`)}>
        {t("export.xlsx")}
      </button>
      {getSvg && (
        <button
          className="btn btn-ghost"
          style={{ padding: "5px 14px", fontSize: 12 }}
          onClick={() => {
            const svg = getSvg();
            if (svg) downloadSvgAsPng(svg, `${baseFilename}.png`);
          }}
        >
          {t("export.png")}
        </button>
      )}
    </div>
  );
}
