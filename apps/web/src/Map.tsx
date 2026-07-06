import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import type { Metric } from "./types";

interface MapProps {
  values: Record<number, number>; // code_muni -> valor do indicador atual
  metric: Metric;
  onSelectMuni: (codeMuni: number, nameMuni: string) => void;
}

const RO_CENTER: [number, number] = [-63.0, -10.9];

export function Map({ values, metric, onSelectMuni }: MapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

  // Inicializa o mapa uma única vez.
  useEffect(() => {
    if (!containerRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {},
        layers: [{ id: "background", type: "background", paint: { "background-color": "#e8eef1" } }],
      },
      center: RO_CENTER,
      zoom: 6,
    });
    mapRef.current = map;

    map.on("load", () => {
      map.addSource("municipios", {
        type: "geojson",
        data: "/geo/municipios_ro.geojson",
        promoteId: "code_muni",
      });

      map.addLayer({
        id: "municipios-fill",
        type: "fill",
        source: "municipios",
        paint: {
          "fill-color": [
            "interpolate",
            ["linear"],
            ["coalesce", ["feature-state", "value"], -1],
            -1, "#cbd5c0",
            0, "#ffedcc",
            1, "#c0392b",
          ],
          "fill-opacity": 0.85,
        },
      });

      map.addLayer({
        id: "municipios-outline",
        type: "line",
        source: "municipios",
        paint: { "line-color": "#4b5b52", "line-width": 0.6 },
      });

      map.on("click", "municipios-fill", (e) => {
        const feature = e.features?.[0];
        if (!feature) return;
        const codeMuni = feature.id as number;
        const nameMuni = (feature.properties?.name_muni as string) ?? "";
        onSelectMuni(codeMuni, nameMuni);
      });

      map.on("mouseenter", "municipios-fill", () => {
        map.getCanvas().style.cursor = "pointer";
      });
      map.on("mouseleave", "municipios-fill", () => {
        map.getCanvas().style.cursor = "";
      });
    });

    return () => map.remove();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Atualiza feature-state quando os valores ou a métrica trocam — sem recriar camada.
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const applyValues = () => {
      const entries = Object.entries(values);
      if (entries.length === 0) return;
      const max = Math.max(...entries.map(([, v]) => v)) || 1;
      for (const [codeMuniStr, value] of entries) {
        map.setFeatureState(
          { source: "municipios", id: Number(codeMuniStr) },
          { value: value / max },
        );
      }
    };

    if (map.isStyleLoaded() && map.getSource("municipios")) {
      applyValues();
    } else {
      map.once("idle", applyValues);
    }
  }, [values, metric]);

  return <div ref={containerRef} style={{ width: "100%", height: "100%" }} />;
}
