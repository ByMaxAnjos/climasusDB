import { createElement, useSyncExternalStore, type ReactNode } from "react";

// ponytail: hash router feito à mão — 4 seções sem rotas aninhadas/loaders não
// justificam react-router-dom, e hash routing evita precisar de rewrite rules
// no bucket estático (GCS não faz path rewrite).

export interface RouteMatch {
  path: string; // segmento inicial, ex. "explore", "catalog", "apps", "docs"
  param: string | null; // segundo segmento, ex. o :dataset/:theme/:page
  query: URLSearchParams;
}

function parseHash(): RouteMatch {
  const raw = window.location.hash.replace(/^#\/?/, ""); // remove "#/" ou "#"
  const [pathPart, queryPart] = raw.split("?");
  const segments = pathPart.split("/").filter(Boolean);
  return {
    path: segments[0] ?? "explore",
    param: segments[1] ?? null,
    query: new URLSearchParams(queryPart ?? ""),
  };
}

// useSyncExternalStore exige que getSnapshot devolva a MESMA referência
// enquanto o hash não mudar — parseHash() cru sempre cria um objeto novo,
// o que causa loop infinito de render. Cacheia por string de hash.
let cachedHash: string | null = null;
let cachedRoute: RouteMatch | null = null;

function getSnapshot(): RouteMatch {
  const hash = window.location.hash;
  if (cachedRoute === null || hash !== cachedHash) {
    cachedHash = hash;
    cachedRoute = parseHash();
  }
  return cachedRoute;
}

function subscribe(callback: () => void): () => void {
  window.addEventListener("hashchange", callback);
  return () => window.removeEventListener("hashchange", callback);
}

export function useRoute(): RouteMatch {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot);
}

export function navigate(path: string): void {
  window.location.hash = path.startsWith("/") ? path : `/${path}`;
}

interface LinkProps {
  to: string;
  children: ReactNode;
  style?: React.CSSProperties;
  className?: string;
}

export function Link({ to, children, style, className }: LinkProps) {
  return createElement(
    "a",
    {
      href: `#${to.startsWith("/") ? to : `/${to}`}`,
      style,
      className,
    },
    children,
  );
}
