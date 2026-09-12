import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";

interface ChartExpandModalProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}

export function ChartExpandModal({ title, onClose, children }: ChartExpandModalProps) {
  const { t } = useTranslation("charts");
  const dialogRef = useRef<HTMLDialogElement>(null);

  // showModal() já dá backdrop, foco preso no diálogo e fechar no Escape
  // (dispara "close") de graça — nada disso precisa ser reimplementado.
  useEffect(() => {
    const dialog = dialogRef.current;
    dialog?.showModal();
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
      {children}
    </dialog>
  );
}
