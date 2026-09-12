// Ícones simples desenhados à mão (stroke, 24x24) — evita puxar uma
// biblioteca de ícones só para ~12 glifos usados nos cards de Catálogo/Apps
// e nos controles do painel de gráficos.
export type IconKey =
  | "antenna"
  | "bar-chart"
  | "flame"
  | "heart"
  | "snowflake"
  | "bug"
  | "wind"
  | "gauge"
  | "link"
  | "shield"
  | "droplet"
  | "expand";

const PATHS: Record<IconKey, React.ReactNode> = {
  antenna: (
    <>
      <path d="M12 2v8" />
      <path d="M8 6c0-2.2 1.8-4 4-4s4 1.8 4 4" />
      <path d="M5 22l4-10h6l4 10" />
      <path d="M9 18h6" />
    </>
  ),
  "bar-chart": (
    <>
      <path d="M4 20V10" />
      <path d="M11 20V4" />
      <path d="M18 20v-7" />
      <path d="M3 20h18" />
    </>
  ),
  flame: <path d="M12 2c1 4-4 5-4 9a4 4 0 0 0 8 0c0-1.5-1-2-1-3.5 1 1 3 3 3 6.5a6 6 0 0 1-12 0C6 9 9 8 12 2z" />,
  heart: <path d="M12 21s-7.5-4.7-10-9.1C.4 8.2 2.3 4.5 6 4.5c2 0 3.5 1.2 4.5 2.7 1-1.5 2.5-2.7 4.5-2.7 3.7 0 5.6 3.7 4 7.4C19.5 16.3 12 21 12 21z" />,
  snowflake: (
    <>
      <path d="M12 2v20" />
      <path d="M4 7l16 10" />
      <path d="M20 7L4 17" />
    </>
  ),
  bug: (
    <>
      <path d="M9 8a3 3 0 0 1 6 0v3H9V8z" />
      <path d="M6 11h12v4a6 6 0 0 1-12 0v-4z" />
      <path d="M2 9l4 3" />
      <path d="M22 9l-4 3" />
      <path d="M2 19l4-3" />
      <path d="M22 19l-4-3" />
      <path d="M12 4V2" />
    </>
  ),
  wind: (
    <>
      <path d="M2 10h13a3 3 0 1 0-3-3" />
      <path d="M2 14h17a3 3 0 1 1-3 3" />
      <path d="M2 18h9" />
    </>
  ),
  gauge: (
    <>
      <path d="M4 15a8 8 0 1 1 16 0" />
      <path d="M12 15l4-5" />
      <circle cx="12" cy="15" r="1.4" fill="currentColor" stroke="none" />
    </>
  ),
  link: (
    <>
      <path d="M9 15l6-6" />
      <path d="M8 13l-2 2a4 4 0 0 0 6 6l2-2" />
      <path d="M16 11l2-2a4 4 0 0 0-6-6l-2 2" />
    </>
  ),
  shield: <path d="M12 2l8 3v6c0 5-3.5 8.5-8 11-4.5-2.5-8-6-8-11V5l8-3z" />,
  droplet: <path d="M12 2s7 8 7 13a7 7 0 1 1-14 0c0-5 7-13 7-13z" />,
  expand: (
    <>
      <path d="M9 3H4v5" />
      <path d="M15 3h5v5" />
      <path d="M20 15v5h-5" />
      <path d="M4 15v5h5" />
    </>
  ),
};

export function Icon({ name, size = 28 }: { name: IconKey; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {PATHS[name]}
    </svg>
  );
}
