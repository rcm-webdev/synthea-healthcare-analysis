# Synthea Healthcare Analysis

A small BI pipeline that turns [Synthea](https://synthetichealth.github.io/synthea/) synthetic
patient data into a governed, KPI-ready dataset: from raw CSV to a data-quality report to a
flat export ready for Tableau (or any BI tool), running entirely on PostgreSQL in a container
and orchestrated through `make`.

## Question

**How do encounter volume, claim cost, payer coverage, encounter type, and organization
activity vary across a healthcare population?**

## Architecture

```
CSV (data/raw/) ──► raw schema ──► analytics.vw_encounter_analysis ──► KPIs / DQ report / CSV export
                     (source-aligned,        (one row per encounter,         (sql/04, sql/05, sql/06)
                      no transforms)          denormalized, derived fields)
```

- **`raw` schema**: `patients`, `encounters`, `organizations`, `payers` loaded straight from
  CSV with no transformation (`sql/01_create_tables.sql`, `sql/02_load_data.sql`). No foreign
  keys are enforced at the DB level; referential integrity is checked explicitly instead (see
  Data quality below).
- **`analytics.vw_encounter_analysis`** (`sql/03_analysis_view.sql`): the semantic layer.
  Grain is **one row per encounter**, left-joined out to patient, organization, and payer
  attributes, with derived fields (`patient_responsibility`, `payer_coverage_rate`,
  `encounter_duration_hours`, `patient_age_at_encounter`) and join-match QA flags
  (`patient_matched`, `organization_matched`, `payer_matched`).

  This is a wide, denormalized "one big table" view rather than a star schema, a reasonable
  choice for a single fact grain at this scale. If more fact types get added later (procedures,
  medications, claims, see Roadmap), shared conformed dimensions become worth the investment.
- **KPI queries** (`sql/04_kpi_queries.sql`): five queries against the view: monthly
  encounter/patient volume with month-over-month change, overall claim-cost profile, payer
  coverage % by payer, encounter-class mix, and a top-20 organization activity ranking.
- **Data-quality report** (`sql/05_data_quality.sql`): 8 checks covering uniqueness,
  completeness, referential integrity, and validity (duplicate IDs, missing keys, unmatched
  patient/organization/payer, negative costs, coverage exceeding claim cost, stop time before
  start time).
- **Tableau export** (`sql/06_tableau_export.sql`, `make export`): flattens the analytics view
  to `data/processed/encounter_analysis.csv`, one row per encounter, ready to point a BI tool
  at directly.

## Getting started

Requires `podman-compose` (or swap `docker-compose` into the Makefile) and the four Synthea
CSVs in `data/raw/`: `patients.csv`, `encounters.csv`, `organizations.csv`, `payers.csv`.

```bash
make setup     # start Postgres, create tables, load CSVs, build the view
make quality   # run the data-quality report
make analysis  # run the five KPI queries
make export    # write data/processed/encounter_analysis.csv for Tableau
make status    # row counts + encounter date range
make stop      # stop Postgres, keep the data volume
make reset     # stop Postgres and delete the data volume
```

`make setup` rebuilds the schema from scratch each time (`DROP SCHEMA ... CASCADE`), so it's
safe to re-run after changing the CSVs or the SQL.

## Data model

| Table | Grain | Rows (sample data) | Notes |
|---|---|---|---|
| `raw.patients` | one row per person | 1,171 | includes Synthea's precomputed lifetime `healthcare_expenses`/`healthcare_coverage`, not yet used downstream |
| `raw.encounters` | one row per healthcare encounter | 53,346 | the fact table; FKs to patient/org/payer, three cost fields |
| `raw.organizations` | one row per facility | 1,119 | |
| `raw.payers` | one row per payer | 10 | includes `NO_INSURANCE` as a real payer row (self-pay), not a null join |
| `analytics.vw_encounter_analysis` | one row per encounter | 53,346 | denormalized join of all four, plus derived fields and QA flags |

Sample data spans encounters from **1912 to 2020**. Synthea simulates full patient lifetimes,
so early decades are sparse-history artifacts, not a real activity ramp-up. Scope
time-series KPIs to a recent window if that noise matters for your chart.

## Data quality

The 8 checks map to a standard framework:

| Dimension | Checks |
|---|---|
| Uniqueness | duplicate encounter IDs |
| Completeness | missing `start_time` / `patient_id` |
| Referential integrity | unmatched patient / organization / payer |
| Validity | negative costs, payer coverage exceeding claim cost, stop time before start time |

Known gaps, not yet covered: **timeliness** (no freshness/staleness check on the data or the
export), and **plausibility** (no bound on `encounter_duration_hours`; a handful of encounters
in the sample data span decades, a Synthea generation artifact that would silently distort any
future length-of-stay metric built on that field).

## Roadmap / next metrics

Fields that already exist in the view or source tables but aren't used by any KPI yet:

- **Length-of-stay** via `encounter_duration_hours`, scoped to inpatient/emergency and with
  outlier bounds applied first.
- **Cost-per-patient / per-capita utilization**: `total_claim_cost` divided by distinct
  patients, rather than per encounter.
- **Payer-mix trend over time**: cross `encounter_month` with payer share and coverage %,
  instead of the current point-in-time snapshot.
- **Claim-cost outlier detection**: the mean and median claim cost are currently almost
  identical, which is worth a percentile/IQR check before trusting the average.
- **Reconciliation check** using `raw.patients.healthcare_expenses`/`healthcare_coverage`
  (Synthea's own lifetime totals) against amounts aggregated from `raw.encounters`.
- **New fact grains**: Synthea also generates `procedures.csv`, `medications.csv`,
  `immunizations.csv`, and `claims.csv`, none of which are loaded by this pipeline yet.

## Tech stack

- PostgreSQL 16 (`postgres:16-alpine`), run via `podman-compose` (`docker-compose.yml`)
- Orchestration via `Makefile`, no separate ETL framework
- Output consumed by Tableau (or any tool that can read a flat CSV)
