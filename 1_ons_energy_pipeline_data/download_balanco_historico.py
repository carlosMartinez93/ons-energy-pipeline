"""
Baixa o dataset "Balanço de Energia nos Subsistemas" (horário) da ONS para um
intervalo de anos. Usa o mesmo padrão de URL e a mesma pasta de saída de
download_ons_data.py (data/raw/balanco_energia_subsistema/<ano>.csv), então o
2024.csv que você já tem é reaproveitado.

Não toca no CMO: o CMO continua só em 2024 (ver README).

Uso (a partir de 1_ons_energy_pipeline_data/):
    python download_balanco_historico.py --probe --from 2015 --to 2025
        -> só verifica quais anos existem na ONS, não baixa nada
    python download_balanco_historico.py --from 2019 --to 2024
        -> baixa; ERRO se algum ano do intervalo não existir
    python download_balanco_historico.py --from 2015 --to 2024 --allow-missing
        -> baixa só os anos que existem e lista os que faltaram
"""

import argparse
import sys
from pathlib import Path

import requests

URL = (
    "https://ons-aws-prod-opendata.s3.amazonaws.com/dataset/"
    "balanco_energia_subsistema_ho/BALANCO_ENERGIA_SUBSISTEMA_{year}.csv"
)
OUTPUT_DIR = Path("./data/raw/balanco_energia_subsistema")

# Colunas que load_balanco_historico_to_bigquery.py e o dbt esperam.
REQUIRED_COLUMNS = {
    "id_subsistema", "nom_subsistema", "din_instante",
    "val_gerhidraulica", "val_gertermica", "val_gereolica", "val_gersolar",
    "val_carga", "val_intercambio",
}


def year_exists(year: int) -> bool:
    """HEAD no arquivo do ano. Bucket público: ano inexistente costuma voltar 403/404."""
    try:
        resp = requests.head(URL.format(year=year), timeout=60, allow_redirects=True)
    except requests.RequestException as exc:
        sys.exit(f"ERRO de rede ao consultar {year}: {exc}")
    return resp.status_code == 200


def check_header(path: Path) -> None:
    """Falha se o CSV não tiver as colunas esperadas (schema pode mudar entre anos)."""
    with path.open("r", encoding="utf-8-sig") as f:
        header = f.readline().strip()
    columns = {c.strip().strip('"') for c in header.split(";")}
    missing = REQUIRED_COLUMNS - columns
    if missing:
        sys.exit(
            f"ERRO: {path.name} não tem as colunas {sorted(missing)}.\n"
            f"Cabeçalho encontrado: {header}\n"
            "O schema desse ano é diferente; não carregue este arquivo sem ajustar o schema."
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--from", dest="year_from", type=int, required=True)
    parser.add_argument("--to", dest="year_to", type=int, required=True)
    parser.add_argument("--probe", action="store_true", help="só verifica quais anos existem")
    parser.add_argument("--allow-missing", action="store_true", help="não falha se faltar ano")
    args = parser.parse_args()

    years = list(range(args.year_from, args.year_to + 1))
    available = [y for y in years if year_exists(y)]
    missing = [y for y in years if y not in available]

    print(f"Disponíveis na ONS: {available}")
    print(f"Ausentes:           {missing}")

    if args.probe:
        return
    if missing and not args.allow_missing:
        sys.exit(
            f"ERRO: anos ausentes {missing}. Rode com --probe para ver o que existe, "
            "ajuste --from/--to ou use --allow-missing."
        )
    if not available:
        sys.exit("ERRO: nenhum ano disponível no intervalo pedido.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for year in available:
        destination = OUTPUT_DIR / f"{year}.csv"
        if destination.exists():
            print(f"Já existe {destination}, pulando download")
        else:
            print(f"Baixando {URL.format(year=year)} ...")
            resp = requests.get(URL.format(year=year), timeout=300)
            resp.raise_for_status()
            if not resp.content:
                sys.exit(f"ERRO: resposta vazia para {year}")
            destination.write_bytes(resp.content)
            print(f"  salvo em {destination} ({len(resp.content) / 1e6:.1f} MB)")
        check_header(destination)

    print(f"\nOK. Anos prontos para carga: {available}")


if __name__ == "__main__":
    main()
