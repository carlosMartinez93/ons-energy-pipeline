"""
Load ONS CSV files into BigQuery as raw tables.

Edit PROJECT_ID and DATASET below, then run:
    python load_to_bigquery.py
"""

from google.cloud import bigquery

PROJECT_ID = "ons-energy-pipeline"
DATASET = "raw_ons"

TABLES = {
    "balanco_energia_subsistema": {
        "file": "data/raw/balanco_energia_subsistema/2024.csv",
        "schema": [
            bigquery.SchemaField("id_subsistema", "STRING"),
            bigquery.SchemaField("nom_subsistema", "STRING"),
            bigquery.SchemaField("din_instante", "TIMESTAMP"),
            bigquery.SchemaField("val_gerhidraulica", "FLOAT64"),
            bigquery.SchemaField("val_gertermica", "FLOAT64"),
            bigquery.SchemaField("val_gereolica", "FLOAT64"),
            bigquery.SchemaField("val_gersolar", "FLOAT64"),
            bigquery.SchemaField("val_carga", "FLOAT64"),
            bigquery.SchemaField("val_intercambio", "FLOAT64"),
        ],
    },
    "cmo_semi_horario": {
        "file": "data/raw/cmo_semi_horario/2024.csv",
        "schema": [
            bigquery.SchemaField("id_subsistema", "STRING"),
            bigquery.SchemaField("nom_subsistema", "STRING"),
            bigquery.SchemaField("din_instante", "TIMESTAMP"),
            bigquery.SchemaField("val_cmo", "FLOAT64"),
        ],
    },
}

client = bigquery.Client(project=PROJECT_ID)

# Make sure the raw dataset exists
dataset_ref = bigquery.Dataset(f"{PROJECT_ID}.{DATASET}")
client.create_dataset(dataset_ref, exists_ok=True)

for table_name, cfg in TABLES.items():
    table_id = f"{PROJECT_ID}.{DATASET}.{table_name}"

    job_config = bigquery.LoadJobConfig(
        schema=cfg["schema"],
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        field_delimiter=";",  # ONS CSVs use semicolon, not comma
        write_disposition="WRITE_TRUNCATE",  # overwrite on re-run, easy to iterate while testing
    )

    with open(cfg["file"], "rb") as f:
        job = client.load_table_from_file(f, table_id, job_config=job_config)

    job.result()  # wait for the job to finish

    table = client.get_table(table_id)
    print(f"Loaded {table.num_rows} rows into {table_id}")