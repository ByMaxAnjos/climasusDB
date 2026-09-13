import { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";

interface ChartExpandModalProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}

export function ChartExpandModal({ title, onClose, children }: ChartExpandModalProps) {
  const { t } = useTranslation("charts");
  const dialogRef = useRef<HTMLDialogElement>(null);
  // Os gráficos filhos medem clientWidth do próprio container no mount. Um
  // <dialog> fechado tem display:none (via :not([open]) do UA stylesheet),
  // então montá-los antes do showModal() rodar mede largura 0 e trava no
  // fallback de 640px — a área do gráfico expandido fica "pela metade".
  // Só monta {children} depois que o diálogo já está aberto e com layout real.
  const [ready, setReady] = useState(false);

  // showModal() já dá backdrop, foco preso no diálogo e fechar no Escape
  // (dispara "close") de graça — nada disso precisa ser reimplementado.
  useEffect(() => {
    const dialog = dialogRef.current;
    dialog?.showModal();
    setReady(true);
  }, []);

  return (
    <dialog
      ref={dialogRef}
      className="chart-expand-modal"
      onClose={onClose}
      onClick={(e) => {
        if (e.target === dialogRef.current) onClose();
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
        <strong style={{ fontSize: 15 }}>{title}</strong>
        <button
          onClick={() => dialogRef.current?.close()}
          aria-label={t("collapse")}
          style={{ border: "none", background: "transparent", cursor: "pointer", fontSize: 18, lineHeight: 1, color: "var(--ink)" }}
        >
          ✕
        </button>
      </div>
      {ready && children}
    </dialog>
  );
}
