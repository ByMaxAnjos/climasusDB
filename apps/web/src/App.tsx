import { useEffect, useState } from "react";
import { Map } from "./Map";
import { TimeSeries } from "./TimeSeries";
import { query, HEALTH_CLIMATE_FILE } from "./db";
import type { HealthClimateRow, Metric } from "./types";
import { METRICS } from "./types";

export function App() {
  const [metric, setMetric] = useState<Metric>("deaths_total");
  const [mapValues, setMapValues] = useState<Record<number, number>>({});
  const [muniOptions, setMuniOptions] = useState<{ code_muni: number; name_muni: string }[]>([]);
  const [selectedMuni, setSelectedMuni] = useState<{ code: number; name: string } | null>(null);
  const [seriesRows, setSeriesRows] = useState<HealthClimateRow[]>([]);
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");

  // Carrega a lista de municípios uma vez (para o seletor) e testa a conexão DuckDB.
  useEffect(() => {
    (async () => {
      try {
        const rows = await query<{ code_muni: number; name_muni: string }>(
          `SELECT DISTINCT code_muni, name_muni FROM '${HEALTH_CLIMATE_FILE}' ORDER BY name_muni`,
        );
        setMuniOptions(rows);
        setStatus("ready");
      } catch (err) {
        console.error("Falha ao consultar DuckDB-WASM:", err);
        setStatus("error");
      }
    })();
  }, []);

  // Recalcula o valor agregado por município (média do indicador no período) para colorir o mapa.
  useEffect(() => {
    if (status !== "ready") return;
    (async () => {
      const agg = metric === "deaths_total" ? "sum" : "avg";
      const rows = await query<{ code_muni: number; value: number }>(
        `SELECT code_muni, ${agg}(${metric}) AS value FROM '${HEALTH_CLIMATE_FILE}' GROUP BY code_muni`,
      );
      const map: Record<number, number> = {};
      for (const r of rows) map[r.code_muni] = r.value;
      setMapValues(map);
    })();
  }, [metric, status]);

  // Busca a série temporal do município selecionado.
  useEffect(() => {
    if (!selectedMuni || status !== "ready") return;
    (async () => {
      const rows = await query<HealthClimateRow>(
        `SELECT * FROM '${HEALTH_CLIMATE_FILE}' WHERE code_muni = ${selectedMuni.code} ORDER BY date`,
      );
      setSeriesRows(rows);
    })();
  }, [selectedMuni, status]);

  function handleSelectMuni(codeMuni: number, nameMuni: string) {
    setSelectedMuni({ code: codeMuni, name: nameMuni });
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100vh", fontFamily: "sans-serif" }}>
      <header style={{ padding: "10px 16px", borderBottom: "1px solid #ddd", display: "flex", gap: 16, alignItems: "center" }}>
        <h1 style={{ fontSize: 18, margin: 0 }}>climasusDB — Atlas (protótipo, dados sintéticos)</h1>
        <label>
          Indicador:{" "}
          <select value={metric} onChange={(e) => setMetric(e.target.value as Metric)}>
            {METRICS.map((m) => (
              <option key={m.key} value={m.key}>
                {m.label}
              </option>
            ))}
          </select>
        </label>
        <label>
          Município:{" "}
          <select
            value={selectedMuni?.code ?? ""}
            onChange={(e) => {
              const opt = muniOptions.find((m) => m.code_muni === Number(e.target.value));
              if (opt) handleSelectMuni(opt.code_muni, opt.name_muni);
            }}
          >
            <option value="">—</option>
            {muniOptions.map((m) => (
              <option key={m.code_muni} value={m.code_muni}>
                {m.name_muni}
              </option>
            ))}
          </select>
        </label>
        {status === "loading" && <span>Carregando motor de consultas local (DuckDB-WASM)…</span>}
        {status === "error" && <span style={{ color: "#c0392b" }}>Erro ao consultar dados.</span>}
      </header>

      <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
        <div style={{ flex: 2 }}>
          <Map values={mapValues} metric={metric} onSelectMuni={handleSelectMuni} />
        </div>
        <div style={{ flex: 1, padding: 16, borderLeft: "1px solid #ddd", overflowY: "auto" }}>
          <TimeSeries rows={seriesRows} metric={metric} muniLabel={selectedMuni?.name ?? null} />
        </div>
      </div>
    </div>
  );
}
