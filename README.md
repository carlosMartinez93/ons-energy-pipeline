# ONS Energy Pipeline

End-to-end analytics engineering pipeline analyzing Brazil's national electric
grid: generation mix by source vs. marginal operation cost (CMO), by
subsystem. Built to demonstrate production-grade data engineering practices
(not just descriptive BI) as part of a broader analytics engineering
portfolio.

**Stack:** Python (ingestion) → BigQuery (raw layer) → dbt Core (staging /
intermediate / marts, tested) → GitHub Actions (CI) → Power BI (consumption)

---

## Problem

Brazil's electricity cost (via the marginal operation cost, CMO) varies
sharply by region and season, but public perception tends to treat it as
uniform. This pipeline builds a dataset that lets you see, per subsystem and
per day, which generation source (hydro, thermal, wind, solar) is on the
margin, and how that relates to cost.

## Data sources

Both datasets come from ONS (Operador Nacional do Sistema Elétrico), Brazil's
grid operator, via its public open data portal (`dados.ons.org.br`):

| Dataset | Grain | What it has |
|---|---|---|
| Balanço de Energia nos Subsistemas | Hourly, per subsystem | Load + generation by source (hydro, thermal, wind, solar), plus interchange |
| CMO Semi-Horário | Half-hourly, per subsystem | Marginal Operation Cost (R$/MWh) |

**Note on PLD vs. CMO:** the commonly-cited "PLD" (Preço de Liquidação das
Diferenças) is published by CCEE, not ONS, and applies regulatory price
caps/floors on top of the CMO. ONS publishes the CMO, which is the underlying
marginal cost signal — the more technically appropriate metric for analyzing
which generation source is driving cost, since it isn't distorted by
regulatory bands.

Scope for this version: 2024 full year, national coverage (4 subsystems: N,
NE, SE, S).

## Architecture

```
download_ons_data.py  →  BigQuery (raw_ons)  →  dbt Core  →  Power BI
                                                      │
                                            staging → intermediate → marts
                                                      │
                                              dbt tests + CI (GitHub Actions)
```

**Ingestion** (`1_ons_energy_pipeline_data/`): plain Python scripts, no
orchestrator — appropriate for the project's size (2 yearly CSV downloads).
`download_ons_data.py` fetches both datasets; `load_to_bigquery.py` loads
them into the `raw_ons` BigQuery dataset.

**Transformation** (`2_ons_energy_cicd/`): dbt Core project with 3 layers:

- **staging** — 1:1 renaming/typing of the two raw sources, no business logic.
- **intermediate** — aggregates the half-hourly CMO to the hourly grain (to
  match the energy balance) and joins generation/load with cost per
  subsystem/hour.
- **marts** — rolls the hourly grain up to daily, computes generation mix
  (% hydro/thermal/wind/solar), and exposes a data-quality signal
  (`hours_with_cost_data` vs. `hours_total`) so consumers can see when a day
  has incomplete cost data instead of it being silently averaged away.

## Key engineering decisions

- **"SIN" is not a 5th subsystem.** The energy balance source includes a
  `SIN` row that's a pre-aggregated national total. It's flagged
  (`is_national_aggregate`) in staging rather than filtered, and excluded
  from the intermediate join (the CMO source has no national-level row, so
  joining it would just produce nulls).
- **Grain mismatch resolved explicitly.** Energy balance is hourly; CMO is
  half-hourly. The intermediate layer averages the two half-hour CMO readings
  per hour before joining — this logic lives in dbt, not in Power BI, so the
  BI layer only ever sees one clean grain.
- **Known data gap, investigated and documented, not silently dropped.**
  Schema inspection surfaced 768 missing rows in the CMO source. Investigation
  (see `investigate_cmo_gap.sql`) found this maps to exactly 4 full days
  (2024-02-08, 2024-02-17, 2024-07-13, 2024-12-29) with zero CMO data across
  all 4 subsystems — consistent with ONS not publishing on those dates
  (national holidays/system maintenance), not a pipeline defect. This is
  captured as a custom dbt test (`test_cmo_no_new_gaps`) that passes as long
  as no *new*, undocumented gaps appear — it would fail if a future ONS
  refresh introduced a different missing-data pattern.

## Testing

10 dbt tests: `unique`/`not_null`/`accepted_values` on the staging and
intermediate models, plus the custom `test_cmo_no_new_gaps` singular test
described above. Run with `dbt test` or `dbt build`.

## CI/CD

GitHub Actions (`.github/workflows/dbt_ci.yml`) runs `dbt build` on every
push/PR to `main`, authenticating to BigQuery via a dedicated service account
(least-privilege: `BigQuery Data Editor` + `BigQuery Job User` only) stored as
a repository secret. CI writes to a separate `dbt_ci` dataset, isolated from
local development (`dbt_dev`).

## Running locally

Requires Python 3.12 (dbt-core does not yet support 3.14) and a GCP project
with BigQuery enabled.

```bash
# 1. Ingest raw data
cd 1_ons_energy_pipeline_data
pip install requests google-cloud-bigquery
python download_ons_data.py
python load_to_bigquery.py

# 2. Set up dbt (Python 3.12 virtual environment)
cd ../2_ons_energy_cicd
py -3.12 -m venv venv_dbt
venv_dbt\Scripts\activate   # Windows
pip install dbt-bigquery

# 3. Authenticate and run
gcloud auth application-default login
dbt debug
dbt build
```

## Status / next steps

- [x] Ingestion, BigQuery load, dbt models (staging/intermediate/marts)
- [x] Data quality tests + documented known gap
- [x] CI/CD via GitHub Actions
- [ ] Power BI report connected to `mart_ons__daily_subsystem_balance`
