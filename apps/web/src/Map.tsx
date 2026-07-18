import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { Protocol } from "pmtiles";
import { MapboxOverlay } from "@deck.gl/mapbox";
import { ScatterplotLayer } from "@deck.gl/layers";
import type { Metric } from "./types";

// Registra o protocolo pmtiles:// uma única vez (nível de módulo) — o
// MapLibre resolve "pmtiles://<url>" delegando a leitura de tiles (via HTTP
// range requests) a este protocolo, sem servidor de tiles.
const pmtilesProtocol = new Protocol();
maplibregl.addProtocol("pmtiles", pmtilesProtocol.tile);

const MUNICIPIOS_SOURCE_LAYER = "municipios"; // definido por --layer= no generate_pmtiles.R
const MUNICIPIOS_PMTILES_URL = `pmtiles://${window.location.origin}/tiles/municipios_br.pmtiles`;

export interface Station {
  station_code: string;
  station_name: string;
  latitude: number;
  longitude: number;
}

interface MapProps {
  values: Record<number, number>; // code_muni -> valor do indicador atual
  metric: Metric;
  stations: Station[]; // camada deck.gl de estações INMET
  // Lista de abbrev_state a exibir — null = Brasil todo. Único mecanismo de
  // filtro, alimentado por Estado, Região (IBGE) OU Agrupamento (bioma/bacia/
  // saúde-agro-geopolítica): todos resolvem para "quais UFs mostrar" antes de
  // chegar aqui, então o mapa não precisa saber qual seletor originou a lista.
  filterUfs: string[] | null;
  onSelectMuni: (codeMuni: number, nameMuni: string) => void;
}

type Bbox = [number, number, number, number]; // [minLon, minLat, maxLon, maxLat]

const BRAZIL_BOUNDS: Bbox = [-73.99, -33.75, -28.85, 5.27];

// ponytail: bbox calculado escaneando coordenadas à mão em vez de puxar
// @turf/turf só para isso — os polígonos já estão em memória (fetch do
// mesmo GeoJSON usado como fonte do mapa).
type NestedCoords = number[] | NestedCoords[];

function extendBbox(bbox: Bbox, coords: NestedCoords): void {
  if (typeof coords[0] === "number") {
    const [x, y] = coords as number[];
    if (x < bbox[0]) bbox[0] = x;
    if (y < bbox[1]) bbox[1] = y;
    if (x > bbox[2]) bbox[2] = x;
    if (y > bbox[3]) bbox[3] = y;
  } else {
    for (const c of coords as NestedCoords[]) extendBbox(bbox, c);
  }
}

function featureBbox(feature: GeoJSON.Feature): Bbox {
  const bbox: Bbox = [Infinity, Infinity, -Infinity, -Infinity];
  extendBbox(bbox, (feature.geometry as GeoJSON.Polygon | GeoJSON.MultiPolygon).coordinates);
  return bbox;
}

function mergeBbox(a: Bbox, b: Bbox): Bbox {
  return [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[2], b[2]), Math.max(a[3], b[3])];
}

export function Map({ values, metric, stations, filterUfs, onSelectMuni }: MapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const overlayRef = useRef<MapboxOverlay | null>(null);
  const estadosRef = useRef<GeoJSON.FeatureCollection | null>(null);
  // ids com feature-state aplicado na última passada — permite limpar estados
  // obsoletos quando a métrica troca para um conjunto menor (ou vazio).
  const appliedIdsRef = useRef<Set<number>>(new Set());

  // Inicializa o mapa uma única vez — basemap CARTO Positron (raster, sem
  // necessidade de chave de API) por baixo das camadas de município.
  useEffect(() => {
    if (!containerRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {
          carto: {
            type: "raster",
            tiles: [
              "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
              "https://b.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
              "https://c.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
              "https://d.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
            ],
            tileSize: 256,
            attribution: "© OpenStreetMap contributors © CARTO",
          },
        },
        layers: [{ id: "carto-basemap", type: "raster", source: "carto" }],
      },
      bounds: BRAZIL_BOUNDS,
      fitBoundsOptions: { padding: 24 },
    });
    mapRef.current = map;

    map.on("load", () => {
      // Sem promoteId aqui: o tippecanoe já promoveu code_muni para o id
      // nativo do tile MVT via --use-attribute-for-id (e removeu o atributo
      // das properties) — promoteId tentaria promover um atributo que não
      // existe mais, sobrescrevendo o id nativo com undefined.
      map.addSource("municipios", {
        type: "vector",
        url: MUNICIPIOS_PMTILES_URL,
      });

      map.addLayer({
        id: "municipios-fill",
        type: "fill",
        source: "municipios",
        "source-layer": MUNICIPIOS_SOURCE_LAYER,
        paint: {
          "fill-color": [
            "interpolate",
            ["linear"],
            ["coalesce", ["feature-state", "value"], -1],
            -1, "#bfe2d7",
            0, "#ffe08a",
            1, "#ff6b4a",
          ],
          "fill-opacity": 0.85,
        },
      });

      map.addLayer({
        id: "municipios-outline",
        type: "line",
        source: "municipios",
        "source-layer": MUNICIPIOS_SOURCE_LAYER,
        paint: { "line-color": "#052e2b", "line-width": 0.4, "line-opacity": 0.25 },
      });

      // Contorno estadual, sempre visível — só orientação, sem interação.
      map.addSource("estados", { type: "geojson", data: "/geo/estados_br.geojson" });
      map.addLayer({
        id: "estados-outline",
        type: "line",
        source: "estados",
        paint: { "line-color": "#052e2b", "line-width": 1, "line-opacity": 0.4 },
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

      // deck.gl interleaved: fica acima dos polígonos, abaixo de rótulos
      // (não há rótulos no estilo mínimo do MVP, mas mantém o padrão certo).
      const overlay = new MapboxOverlay({ interleaved: true, layers: [] });
      overlayRef.current = overlay;
      map.addControl(overlay as unknown as maplibregl.IControl);
    });

    fetch("/geo/estados_br.geojson")
      .then((res) => res.json())
      .then((fc: GeoJSON.FeatureCollection) => {
        estadosRef.current = fc;
      })
      .catch(() => {
        // Sem o geojson, o fitBounds degrada para BRAZIL_BOUNDS — aceitável.
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
      const next = new Set<number>();
      // min-max, não value/max: métricas com piso != 0 (ex. risco relativo
      // do DLNM, ~0.85-1.07) ficariam todas amontoadas perto de 1.0 num
      // ramp 0-1 baseado só no máximo. min-max usa a faixa real dos dados,
      // e continua idêntico a antes pras métricas com piso 0 (deaths_total
      // etc.), já que min=0 nesse caso.
      if (entries.length > 0) {
        const vals = entries.map(([, v]) => v);
        const min = Math.min(...vals);
        const max = Math.max(...vals);
        const range = max - min || 1;
        for (const [codeMuniStr, value] of entries) {
          const id = Number(codeMuniStr);
          map.setFeatureState(
            { source: "municipios", sourceLayer: MUNICIPIOS_SOURCE_LAYER, id },
            { value: (value - min) / range },
          );
          next.add(id);
        }
      }
      // Limpa estados que saíram do conjunto — sem isso, trocar para uma
      // métrica sem dados deixaria o choropleth anterior congelado no mapa.
      for (const id of appliedIdsRef.current) {
        if (!next.has(id)) {
          map.removeFeatureState({ source: "municipios", sourceLayer: MUNICIPIOS_SOURCE_LAYER, id });
        }
      }
      appliedIdsRef.current = next;
    };

    if (map.isStyleLoaded() && map.getSource("municipios")) {
      applyValues();
      return;
    }
    map.once("idle", applyValues);
    return () => { map.off("idle", applyValues); };
  }, [values, metric]);

  // Filtro por Estado/Região/Agrupamento — restringe quais municípios aparecem
  // coloridos e ajusta o zoom/pan para a área selecionada (ou volta ao Brasil
  // todo). Os três seletores já resolvem para a mesma coisa antes de chegar
  // aqui: uma lista de abbrev_state.
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const applyFilter = () => {
      const filter: maplibregl.FilterSpecification | null = filterUfs
        ? ["in", ["get", "abbrev_state"], ["literal", filterUfs]]
        : null;

      map.setFilter("municipios-fill", filter);
      map.setFilter("municipios-outline", filter);

      const estados = estadosRef.current;
      let bbox = BRAZIL_BOUNDS;
      if (estados && filterUfs) {
        const matching = estados.features.filter((f) => filterUfs.includes(f.properties?.abbrev_state));
        if (matching.length > 0) {
          bbox = matching.map(featureBbox).reduce(mergeBbox);
        }
      }
      map.fitBounds(
        [
          [bbox[0], bbox[1]],
          [bbox[2], bbox[3]],
        ],
        { padding: 40, duration: 600 },
      );
    };

    if (map.isStyleLoaded() && map.getSource("municipios")) {
      applyFilter();
      return;
    }
    map.once("idle", applyFilter);
    return () => { map.off("idle", applyFilter); };
  }, [filterUfs]);

  // Camada de estações INMET — atualiza sem tocar nos polígonos de município.
  useEffect(() => {
    overlayRef.current?.setProps({
      layers: [
        new ScatterplotLayer<Station>({
          id: "inmet-stations",
          data: stations,
          getPosition: (d) => [d.longitude, d.latitude],
          getRadius: 6000,
          getFillColor: [29, 155, 240, 210],
          getLineColor: [255, 255, 255],
          lineWidthMinPixels: 1,
          stroked: true,
          pickable: true,
        }),
      ],
    });
  }, [stations]);

  return <div ref={containerRef} style={{ width: "100%", height: "100%" }} />;
}
