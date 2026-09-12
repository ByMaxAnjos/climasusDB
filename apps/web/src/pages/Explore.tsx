import { useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { Map, type Station } from "../Map";
import { ChartPanel, type ChartView } from "../components/charts/ChartPanel";
import type { SeasonalityRow } from "../components/charts/SeasonalityChart";
import {
  query,
  dataUrl,
  HEALTH_CLIMATE_FILE,
  DIM_STATION_FILE,
  DLNM_EXPOSURE_FILE,
  DLNM_LAG_FILE,
  DLNM_SURFACE_FILE,
  isDlnmAvailable,
} from "../db";
import type { DlnmExposureRow, DlnmLagRow, DlnmSurfaceRow, HealthClimateRow, Metric } from "../types";
import { METRICS, isDlnmMetric } from "../types";
import { useRoute } from "../router";
import { getTheme } from "../data/featured-themes";
import { STATE_GROUPS, GROUP_CATEGORIES, getStateGroup } from "../data/state-groups";

interface MuniOption {
  code_muni: number;
  name_muni: string;
  abbrev_state: string;
  code_region: number;
}
interface RegionOption {
  code_region: number;
  name_region: string;
}
interface UfOption {
  abbrev_state: string;
  name_state: string;
  code_region: number;
}

export function Explore({ forcedThemeId }: { forcedThemeId?: string } = {}) {
  const { t, i18n } = useTranslation();
  const { query: urlQuery } = useRoute();
  const theme = getTheme(forcedThemeId ?? urlQuery.get("theme"));
  const [metric, setMetric] = useState<Metric>(theme?.explorePreset.metric ?? "deaths_total");
  const [mapValues, setMapValues] = useState<Record<number, number>>({});
  const [allMunis, setAllMunis] = useState<MuniOption[]>([]);
  const [regionOptions, setRegionOptions] = useState<RegionOption[]>([]);
  const [ufOptions, setUfOptions] = useState<UfOption[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<number | "">("");
  const [selectedUf, setSelectedUf] = useState<string>("");
  const [selectedGroup, setSelectedGroup] = useState<string>("");
  const [selectedMuni, setSelectedMuni] = useState<{ code: number; name: string } | null>(null);
  const [seriesRows, setSeriesRows] = useState<HealthClimateRow[]>([]);
  const [seasonalityRows, setSeasonalityRows] = useState<SeasonalityRow[]>([]);
  const [stations, setStations] = useState<Station[]>([]);
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const [view, setView] = useState<ChartView>("timeseries");
  // Indicador DLNM (Fase 2b) — grão UF, não município x dia; ver ChartPanel.tsx.
  const [dlnmReady, setDlnmReady] = useState(false);
  const [dlnmExposureRows, setDlnmExposureRows] = useState<DlnmExposureRow[]>([]);
  const [dlnmLagRows, setDlnmLagRows] = useState<DlnmLagRow[]>([]);
  const [dlnmSurfaceRows, setDlnmSurfaceRows] = useState<DlnmSurfaceRow[]>([]);

  // Malha nacional de municípios (para os seletores de Região/Estado/Município
  // e para os polígonos do mapa, servidos separadamente pelo MapLibre).
  useEffect(() => {
    (async () => {
      try {
        const res = await fetch(dataUrl("/geo/municipios_br.geojson"));
        const fc = (await res.json()) as GeoJSON.FeatureCollection;
        const munis: MuniOption[] = fc.features
          .map((f) => f.properties as MuniOption)
          .sort((a, b) => a.name_muni.localeCompare(b.name_muni));
        setAllMunis(munis);

        // `new Map(...)` (built-in) colidiria com o componente <Map> importado
        // acima — usamos objetos simples para deduplicar região/estado.
        const regions: Record<number, string> = {};
        const ufs: Record<string, UfOption> = {};
        for (const f of fc.features) {
          const p = f.properties as MuniOption & { name_state: string; name_region: string };
          regions[p.code_region] = p.name_region;
          ufs[p.abbrev_state] = { abbrev_state: p.abbrev_state, name_state: p.name_state, code_region: p.code_region };
        }
        setRegionOptions(
          Object.entries(regions)
            .map(([code_region, name_region]) => ({ code_region: Number(code_region), name_region }))
            .sort((a, b) => a.name_region.localeCompare(b.name_region)),
        );
        setUfOptions(Object.values(ufs).sort((a, b) => a.name_state.localeCompare(b.name_state)));
        setStatus("ready");
      } catch (err) {
        console.error("Falha ao carregar a malha municipal:", err);
        setStatus("error");
      }
    })();
  }, []);

  // Estações INMET (camada deck.gl) — dataset independente, sem dado sintético.
  // Aproveita essa primeira query pós-status="ready" pra também checar se os
  // 3 datasets DLNM (Fase 2b, opcionais — `make dlnm`) existem no catálogo.
  useEffect(() => {
    if (status !== "ready") return;
    let cancelled = false;
    (async () => {
      try {
        const rows = await query<Station>(`SELECT * FROM '${DIM_STATION_FILE}'`);
        if (cancelled) return;
        setStations(rows);
        setDlnmReady(isDlnmAvailable());
      } catch (err) {
        if (!cancelled) {
          console.error("Falha ao carregar estações INMET:", err);
          setStatus("error");
        }
      }
    })();
    return () => { cancelled = true; };
  }, [status]);

  // Recalcula o valor agregado por município para colorir o mapa. O
  // indicador DLNM tem grão UF (não município x dia): busca o RR de cada UF
  // no p75 (referência fixa) e transmite (broadcast) o mesmo valor a todos
  // os municípios daquela UF — mapValues continua code_muni -> number, então
  // Map.tsx não precisa saber que a origem do dado é diferente.
  useEffect(() => {
    if (status !== "ready") return;
    let cancelled = false;
    (async () => {
      try {
        if (isDlnmMetric(metric)) {
          if (!dlnmReady) { setMapValues({}); return; }
          const rows = await query<{ uf: string; rr: number }>(
            `SELECT uf, rr FROM '${DLNM_EXPOSURE_FILE}' WHERE pct = 0.75`,
          );
          if (cancelled) return;
          const rrByUf: Record<string, number> = {};
          for (const r of rows) rrByUf[r.uf] = r.rr;
          const map: Record<number, number> = {};
          for (const m of allMunis) {
            if (m.abbrev_state in rrByUf) map[m.code_muni] = rrByUf[m.abbrev_state];
          }
          setMapValues(map);
          return;
        }
        const agg = metric === "deaths_total" ? "sum" : "avg";
        const rows = await query<{ code_muni: number; value: number }>(
          `SELECT code_muni, CAST(${agg}(${metric}) AS DOUBLE) AS value FROM '${HEALTH_CLIMATE_FILE}' GROUP BY code_muni`,
        );
        if (cancelled) return;
        const map: Record<number, number> = {};
        for (const r of rows) map[r.code_muni] = r.value;
        setMapValues(map);
      } catch (err) {
        if (!cancelled) {
          console.error("Falha ao agregar indicador para o mapa:", err);
          setStatus("error");
        }
      }
    })();
    return () => { cancelled = true; };
  }, [metric, status, dlnmReady, allMunis]);

  // Busca a série temporal do município selecionado (não aplicável ao DLNM).
  useEffect(() => {
    if (!selectedMuni || status !== "ready" || isDlnmMetric(metric)) return;
    let cancelled = false;
    (async () => {
      try {
        const rows = await query<HealthClimateRow>(
          `SELECT * FROM '${HEALTH_CLIMATE_FILE}' WHERE code_muni = ${selectedMuni.code} ORDER BY date`,
        );
        if (!cancelled) setSeriesRows(rows);
      } catch (err) {
        if (!cancelled) console.error("Falha ao carregar série do município:", err);
      }
    })();
    return () => { cancelled = true; };
  }, [selectedMuni, status, metric]);

  // Os 3 gráficos DLNM são por UF: acha a UF do município selecionado e
  // busca as curvas dessa UF nos 3 datasets (exposição-resposta, lag,
  // superfície). Roda só quando o indicador ativo é o DLNM.
  useEffect(() => {
    if (!selectedMuni || status !== "ready" || !isDlnmMetric(metric) || !dlnmReady) {
      setDlnmExposureRows([]);
      setDlnmLagRows([]);
      setDlnmSurfaceRows([]);
      return;
    }
    const uf = allMunis.find((m) => m.code_muni === selectedMuni.code)?.abbrev_state;
    if (!uf) return;
    let cancelled = false;
    (async () => {
      try {
        const [expo, lag, surf] = await Promise.all([
          query<DlnmExposureRow>(`SELECT * FROM '${DLNM_EXPOSURE_FILE}' WHERE uf = '${uf}'`),
          query<DlnmLagRow>(`SELECT * FROM '${DLNM_LAG_FILE}' WHERE uf = '${uf}'`),
          query<DlnmSurfaceRow>(`SELECT * FROM '${DLNM_SURFACE_FILE}' WHERE uf = '${uf}'`),
        ]);
        if (cancelled) return;
        setDlnmExposureRows(expo);
        setDlnmLagRows(lag);
        setDlnmSurfaceRows(surf);
      } catch (err) {
        if (!cancelled) console.error("Falha ao carregar curvas DLNM:", err);
      }
    })();
    return () => { cancelled = true; };
  }, [selectedMuni, status, metric, dlnmReady, allMunis]);

  // Sazonalidade mensal (média/soma do indicador por mês, todos os anos) do município selecionado.
  useEffect(() => {
    if (!selectedMuni || status !== "ready" || isDlnmMetric(metric)) {
      setSeasonalityRows([]);
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const agg = metric === "deaths_total" ? "sum" : "avg";
        const rows = await query<SeasonalityRow>(
          `SELECT CAST(strftime(date, '%m') AS INTEGER) AS month, CAST(${agg}(${metric}) AS DOUBLE) AS value
           FROM '${HEALTH_CLIMATE_FILE}' WHERE code_muni = ${selectedMuni.code} GROUP BY month ORDER BY month`,
        );
        if (!cancelled) setSeasonalityRows(rows);
      } catch (err) {
        if (!cancelled) console.error("Falha ao carregar sazonalidade:", err);
      }
    })();
    return () => { cancelled = true; };
  }, [selectedMuni, metric, status]);

  function handleSelectMuni(codeMuni: number, nameMuni: string) {
    setSelectedMuni({ code: codeMuni, name: nameMuni });
  }

  const muniNames = useMemo(() => {
    const map: Record<number, string> = {};
    for (const m of allMunis) map[m.code_muni] = m.name_muni;
    return map;
  }, [allMunis]);

  // Único mecanismo de escopo geográfico: Estado, Região (IBGE) e Agrupamento
  // (bioma/bacia/saúde-agro-geopolítica) são mutuamente exclusivos — cada um
  // resolve para a mesma coisa, uma lista de abbrev_state, ou null (Brasil
  // todo). Estado tem prioridade (mais específico), depois Região, depois
  // Agrupamento.
  const filterUfs = useMemo(() => {
    if (selectedUf) return [selectedUf];
    if (selectedRegion !== "") return ufOptions.filter((u) => u.code_region === selectedRegion).map((u) => u.abbrev_state);
    if (selectedGroup) return getStateGroup(selectedGroup)?.ufs ?? null;
    return null;
  }, [selectedUf, selectedRegion, selectedGroup, ufOptions]);

  // Restringe os valores do mapa (já agregados nacionalmente) ao escopo
  // selecionado, para a comparação entre municípios — sem nova query.
  const comparisonValues = useMemo(() => {
    if (!filterUfs) return mapValues;
    const allowed = new Set(allMunis.filter((m) => filterUfs.includes(m.abbrev_state)).map((m) => m.code_muni));
    const filtered: Record<number, number> = {};
    for (const [code, value] of Object.entries(mapValues)) {
      if (allowed.has(Number(code))) filtered[Number(code)] = value;
    }
    return filtered;
  }, [mapValues, allMunis, filterUfs]);

  const scopeLabel = useMemo(() => {
    if (selectedUf) return ufOptions.find((u) => u.abbrev_state === selectedUf)?.name_state ?? selectedUf;
    if (selectedRegion !== "") return regionOptions.find((r) => r.code_region === selectedRegion)?.name_region ?? String(selectedRegion);
    if (selectedGroup) return t(`groups:names.${selectedGroup}`);
    return t("charts:brazil_scope");
  }, [selectedUf, selectedRegion, selectedGroup, ufOptions, regionOptions, t]);

  // Valor único do <select> combinado Região/Agrupamento — as duas fontes
  // são mutuamente exclusivas, então codificamos qual delas está ativa no
  // próprio value ("region:<code_region>" | "group:<id>").
  const combinedRegionValue = selectedRegion !== "" ? `region:${selectedRegion}` : selectedGroup ? `group:${selectedGroup}` : "";

  function handleRegionOrGroupChange(value: string) {
    if (value.startsWith("region:")) {
      setSelectedRegion(Number(value.slice("region:".length)));
      setSelectedGroup("");
    } else if (value.startsWith("group:")) {
      setSelectedGroup(value.slice("group:".length));
      setSelectedRegion("");
    } else {
      setSelectedRegion("");
      setSelectedGroup("");
    }
    setSelectedUf("");
    setSelectedMuni(null);
  }

  const visibleUfOptions = useMemo(
    () => (selectedRegion === "" ? ufOptions : ufOptions.filter((u) => u.code_region === selectedRegion)),
    [ufOptions, selectedRegion],
  );

  const visibleMuniOptions = useMemo(
    () => (filterUfs ? allMunis.filter((m) => filterUfs.includes(m.abbrev_state)) : allMunis),
    [allMunis, filterUfs],
  );

  // Rótulo da UF do município selecionado, pros títulos dos 3 gráficos DLNM
  // (o modelo é ajustado por UF inteira, não por município — ver dlnm.R).
  const dlnmUfLabel = useMemo(() => {
    if (!selectedMuni) return null;
    const uf = allMunis.find((m) => m.code_muni === selectedMuni.code)?.abbrev_state;
    if (!uf) return null;
    const name = ufOptions.find((u) => u.abbrev_state === uf)?.name_state;
    return name ? `${name} (${uf})` : uf;
  }, [selectedMuni, allMunis, ufOptions]);

  return (
    <div style={{ display: "flex", flexDirection: "column", flex: 1, minHeight: 0 }}>
      <header
        style={{
          padding: "12px 24px",
          borderBottom: "1px solid var(--rule)",
          background: "var(--paper-3)",
          display: "flex",
          gap: 20,
          alignItems: "center",
          flexWrap: "wrap",
        }}
      >
        <label style={{ fontSize: 14, color: "var(--muted)" }}>
          {t("indicator")}:{" "}
          <select value={metric} onChange={(e) => setMetric(e.target.value as Metric)}>
            {METRICS.filter((m) => !isDlnmMetric(m.key) || dlnmReady).map((m) => (
              <option key={m.key} value={m.key}>
                {t(`metric.${m.key}`)}
              </option>
            ))}
          </select>
        </label>
        <label style={{ fontSize: 14, color: "var(--muted)" }}>
          {t("region")}:{" "}
          <select value={combinedRegionValue} onChange={(e) => handleRegionOrGroupChange(e.target.value)}>
            <option value="">—</option>
            <optgroup label={t("region_ibge")}>
              {regionOptions.map((r) => (
                <option key={r.code_region} value={`region:${r.code_region}`}>
                  {r.name_region}
                </option>
              ))}
            </optgroup>
            {GROUP_CATEGORIES.map((category) => (
              <optgroup key={category} label={t(`groups:categories.${category}`)}>
                {STATE_GROUPS.filter((g) => g.category === category).map((g) => (
                  <option key={g.id} value={`group:${g.id}`}>
                    {t(`groups:names.${g.id}`)}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </label>
        <label style={{ fontSize: 14, color: "var(--muted)" }}>
          {t("state")}:{" "}
          <select
            value={selectedUf}
            onChange={(e) => {
              setSelectedUf(e.target.value);
              setSelectedGroup("");
              setSelectedMuni(null);
            }}
          >
            <option value="">—</option>
            {visibleUfOptions.map((u) => (
              <option key={u.abbrev_state} value={u.abbrev_state}>
                {u.name_state}
              </option>
            ))}
          </select>
        </label>
        <label style={{ fontSize: 14, color: "var(--muted)" }}>
          {t("municipality")}:{" "}
          <select
            value={selectedMuni?.code ?? ""}
            onChange={(e) => {
              const opt = visibleMuniOptions.find((m) => m.code_muni === Number(e.target.value));
              if (opt) handleSelectMuni(opt.code_muni, opt.name_muni);
            }}
          >
            <option value="">—</option>
            {visibleMuniOptions.map((m) => (
              <option key={m.code_muni} value={m.code_muni}>
                {m.name_muni}
              </option>
            ))}
          </select>
        </label>
        <label style={{ marginLeft: "auto" }}>
          <select aria-label={t("language")} value={i18n.language} onChange={(e) => i18n.changeLanguage(e.target.value)}>
            <option value="pt">PT</option>
            <option value="en">EN</option>
            <option value="es">ES</option>
          </select>
        </label>
        {status === "loading" && <span className="badge badge-muted">{t("loading")}</span>}
        {status === "error" && <span style={{ color: "var(--heat)" }}>{t("error")}</span>}
      </header>

      <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
        <div style={{ flex: 2 }}>
          <Map values={mapValues} metric={metric} stations={stations} filterUfs={filterUfs} onSelectMuni={handleSelectMuni} />
        </div>
        <div style={{ flex: 1, padding: 20, borderLeft: "1px solid var(--rule)", background: "var(--paper-3)", overflowY: "auto" }}>
          <ChartPanel
            view={view}
            onViewChange={setView}
            metric={metric}
            muniLabel={selectedMuni?.name ?? null}
            seriesRows={seriesRows}
            seasonalityRows={seasonalityRows}
            comparisonValues={comparisonValues}
            muniNames={muniNames}
            scopeLabel={scopeLabel}
            dlnmUfLabel={dlnmUfLabel}
            dlnmExposureRows={dlnmExposureRows}
            dlnmLagRows={dlnmLagRows}
            dlnmSurfaceRows={dlnmSurfaceRows}
          />
        </div>
      </div>
    </div>
  );
}
