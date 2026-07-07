"""
Inspect the ONS CSV files with DuckDB: schema, sample rows, row count.

Usage:
    python inspect_ons_data.py
"""

import duckdb

FILES = {
    "balanco_energia_subsistema": "data/raw/balanco_energia_subsistema/2024.csv",
    "cmo_semi_horario": "data/raw/cmo_semi_horario/2024.csv",
}

con = duckdb.connect()

for name, path in FILES.items():
    print(f"\n=== {name} ===")

    print("\n-- schema --")
    print(con.execute(f"DESCRIBE SELECT * FROM '{path}'").fetchdf())

    print("\n-- sample rows --")
    print(con.execute(f"SELECT * FROM '{path}' LIMIT 5").fetchdf())

    print("\n-- row count --")
    print(con.execute(f"SELECT COUNT(*) AS total_rows FROM '{path}'").fetchdf())