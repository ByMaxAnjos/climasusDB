import writeXlsxFile from "write-excel-file/browser";

function triggerDownload(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function csvEscape(value: unknown): string {
  const s = value == null ? "" : String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function downloadCsv(rows: Record<string, unknown>[], filename: string): void {
  if (rows.length === 0) return;
  const columns = Object.keys(rows[0]);
  const lines = [columns.join(","), ...rows.map((r) => columns.map((c) => csvEscape(r[c])).join(","))];
  triggerDownload(new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8" }), filename);
}

export async function downloadXlsx(rows: Record<string, unknown>[], filename: string): Promise<void> {
  if (rows.length === 0) return;
  const keys = Object.keys(rows[0]);
  const columns = keys.map((key) => ({
    header: key,
    cell: (row: Record<string, unknown>) => (row[key] as string | number | null | undefined) ?? null,
  }));
  await writeXlsxFile(rows, { columns }).toFile(filename);
}

// Serializa o <svg> renderizado pelo Observable Plot para PNG via canvas —
// evita puxar uma lib de export só para isso (o SVG já está no DOM).
export function downloadSvgAsPng(svg: SVGSVGElement, filename: string): void {
  const width = svg.width?.baseVal?.value || svg.clientWidth || 640;
  const height = svg.height?.baseVal?.value || svg.clientHeight || 320;
  const clone = svg.cloneNode(true) as SVGSVGElement;
  clone.setAttribute("width", String(width));
  clone.setAttribute("height", String(height));

  const svgString = new XMLSerializer().serializeToString(clone);
  const svgBlob = new Blob([svgString], { type: "image/svg+xml;charset=utf-8" });
  const url = URL.createObjectURL(svgBlob);

  const image = new Image();
  image.onload = () => {
    const scale = 2; // exporta em 2x para ficar nítido fora da tela
    const canvas = document.createElement("canvas");
    canvas.width = width * scale;
    canvas.height = height * scale;
    const ctx = canvas.getContext("2d")!;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.scale(scale, scale);
    ctx.drawImage(image, 0, 0, width, height);
    URL.revokeObjectURL(url);
    canvas.toBlob((blob) => {
      if (blob) triggerDownload(blob, filename);
    }, "image/png");
  };
  image.src = url;
}
