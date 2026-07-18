import type { ReactNode } from "react";
import { Icon, type IconKey } from "./Icon";

interface CardMediaProps {
  icon: IconKey;
  gradient: string;
  title: string;
  description: string;
  footer?: ReactNode;
}

// Corpo compartilhado dos cards com imagem (Catálogo de Dados/Aplicações) —
// o chamador envolve isto num <Link className="card card-media"> ou <div>.
export function CardMedia({ icon, gradient, title, description, footer }: CardMediaProps) {
  return (
    <>
      <div className="card-media__img" style={{ background: gradient }}>
        <Icon name={icon} size={36} />
      </div>
      <div className="card-media__body">
        <h3 style={{ margin: 0, fontSize: 19 }}>{title}</h3>
        <p className="page-lede" style={{ margin: 0, fontSize: 13.5 }}>
          {description}
        </p>
        {footer}
      </div>
    </>
  );
}
