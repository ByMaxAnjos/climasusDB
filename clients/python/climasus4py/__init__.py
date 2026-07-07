"""climasus4py — leitura Python dos datasets Gold do climasusDB.

Esqueleto inicial (Fase 6): lê Parquet local recuperando a proveniência
`climasus_meta` embutida pelo climasus4r (mesma chave, mesmo JSON — o
contrato de metadados é compartilhado entre R e Python, não duplicado).

Leitura remota (https://.../data.parquet) fica fora deste esqueleto de
propósito: pyarrow sozinho não fala HTTP; a rota real é DuckDB
(`duckdb.read_parquet(url)`, já usado no frontend) ou `fsspec`+`httpfs` —
adicionar quando houver um caso de uso real além do MVP local.
"""

from .read_gold import GoldDataset, read_gold

__all__ = ["GoldDataset", "read_gold"]
__version__ = "0.1.0"
