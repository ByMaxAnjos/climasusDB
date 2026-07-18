// IDs de página de documentação — cada um vira uma chave `docs:page.<id>.*`
// nos arquivos de locale (public/locales/*/docs.json).
export const DOC_PAGE_IDS = ["data-model", "querying", "catalog-contract", "heat-cardio"] as const;
export type DocPageId = (typeof DOC_PAGE_IDS)[number];
