import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // ponytail: sem otimização extra de deps aqui — duckdb-wasm funciona com o
  // pré-bundling default do Vite neste tamanho de projeto; revisitar se o dev
  // server engasgar ao carregar o worker.
});
