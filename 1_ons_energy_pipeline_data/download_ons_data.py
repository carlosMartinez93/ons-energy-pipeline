"""
Downloader for ONS open data (Brazil's electric system operator).

Just edit YEARS below and run:
    python download_ons_data.py
"""

import requests
from pathlib import Path

# Edit this to choose which years to download
YEARS = [2024]

# One CSV file per year, same URL pattern for both datasets
DATASETS = {
    "balanco_energia_subsistema": "https://ons-aws-prod-opendata.s3.amazonaws.com/dataset/balanco_energia_subsistema_ho/BALANCO_ENERGIA_SUBSISTEMA_{year}.csv",
    "cmo_semi_horario": "https://ons-aws-prod-opendata.s3.amazonaws.com/dataset/cmo_tm/CMO_SEMIHORARIO_{year}.csv",
}

OUTPUT_DIR = Path("./data/raw")

for name, url_template in DATASETS.items():
    for year in YEARS:
        url = url_template.format(year=year)
        destination = OUTPUT_DIR / name / f"{year}.csv"
        destination.parent.mkdir(parents=True, exist_ok=True)

        if destination.exists():
            print(f"Already have {destination}, skipping")
            continue

        print(f"Downloading {url} ...")
        response = requests.get(url)
        response.raise_for_status()
        destination.write_bytes(response.content)
        print(f"Saved to {destination}")