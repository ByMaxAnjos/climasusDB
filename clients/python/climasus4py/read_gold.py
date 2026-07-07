from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pyarrow.parquet as pq


@dataclass
class GoldDataset:
    """Um dataset Gold lido do climasusDB, com sua proveniência."""

    table: "pq.Table"
    meta: dict[str, Any]

    def to_pandas(self):
        return self.table.to_pandas()


def read_gold(path: str | Path) -> GoldDataset:
    """Lê um Parquet Gold do climasusDB, recuperando a chave `climasus_meta`
    embutida no schema Arrow pelo `write_parquet_climasus()` do climasus4r.

    Levanta `ValueError` se a chave estiver ausente — mesmo contrato do
    `catalog.R`/`assert_climasus_meta()` no lado R: um Parquet sem
    proveniência não é considerado um dataset Gold válido da plataforma.
    """
    table = pq.read_table(path)
    raw_meta = table.schema.metadata.get(b"climasus_meta") if table.schema.metadata else None
    if raw_meta is None:
        raise ValueError(f"Parquet sem climasus_meta (proveniência ausente): {path}")

    meta = json.loads(raw_meta.decode("utf-8"))
    return GoldDataset(table=table, meta=meta)
