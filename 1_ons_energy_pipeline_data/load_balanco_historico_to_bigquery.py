"""
Carrega TODOS os CSVs de data/raw/balanco_energia_subsistema/*.csv em UMA tabela
multi-ano no BigQuery: raw_ons.balanco_energia_subsistema_historico.

Por que uma tabela nova e não a existente (raw_ons.balanco_energia_subsistema)?
A tabela existente alimenta o mart de custo (CMO), que só tem 2024. Se ela ganhasse
outros anos, o join com o CMO geraria dias sem custo e o teste test_cmo_no_new_gaps
passaria a falhar. A tabela nova alimenta apenas o mart de geração mensal.

Uso (a partir de 1_ons_energy_pipeline_data/):
    python load_balanco_historico_to_bigquery.py

Reexecutar é seguro: a tabela é recriada do zero a cada execução.
"""

import sys
from pathlib import Path

from google.cloud import bigquery

PROJECT_ID = "ons-energy-pipeline"
DATASET = "raw_ons"
TABLE = "balanco_energia_subsistema_historico"
RAW_DIR = Path("data/raw/balanco_energia_subsistema")

SCHEMA = [
    bigquery.SchemaField("id_subsistema", "STRING"),
    bigquery.SchemaField("nom_subsistema", "STRING"),
    bigquery.SchemaField("din_instante", "TIMESTAMP"),
    bigquery.SchemaField("val_gerhidraulica", "FLOAT64"),
    bigquery.SchemaField("val_gertermica", "FLOAT64"),
    bigquery.SchemaField("val_gereolica", "FLOAT64"),
    bigquery.SchemaField("val_gersolar", "FLOAT64"),
    bigquery.SchemaField("val_carga", "FLOAT64"),
    bigquery.SchemaField("val_intercambio", "FLOAT64"),
]


def count_data_rows(path: Path) -> int:
    """Linhas do CSV sem o cabeçalho."""
    with path.open("rb") as f:
        return sum(1 for _ in f) - 1


def main() -> None:
    files = sorted(RAW_DIR.glob("*.csv"))
    if not files:
        sys.exit(f"ERRO: nenhum CSV em {RAW_DIR.resolve()}. Rode download_balanco_historico.py antes.")

    client = bigquery.Client(project=PROJECT_ID)
    client.create_dataset(bigquery.Dataset(f"{PROJECT_ID}.{DATASET}"), exists_ok=True)
    table_id = f"{PROJECT_ID}.{DATASET}.{TABLE}"

    expected_rows = 0
    for i, path in enumerate(files):
        job_config = bigquery.LoadJobConfig(
            schema=SCHEMA,
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            field_delimiter=";",
            write_disposition="WRITE_TRUNCATE" if i == 0 else "WRITE_APPEND",
        )
        with path.open("rb") as f:
            job = client.load_table_from_file(f, table_id, job_config=job_config)
        job.result()  # levanta exceção se o schema do CSV não bater
        rows = count_data_rows(path)
        expected_rows += rows
        print(f"{path.name}: {rows:,} linhas enviadas")

    loaded = client.get_table(table_id).num_rows
    print(f"\nEsperado (soma dos CSVs): {expected_rows:,} | na tabela: {loaded:,}")
    if loaded != expected_rows:
        sys.exit("ERRO: contagem de linhas na tabela difere da soma dos CSVs. Não siga adiante.")
    print(f"OK: {table_id}")


if __name__ == "__main__":
    main()
