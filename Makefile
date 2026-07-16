SHELL := /bin/bash

COMPOSE := podman-compose
PSQL := $(COMPOSE) exec -T postgres psql -U synthea -d synthea -v ON_ERROR_STOP=1
RAW_FILES := data/raw/patients.csv data/raw/encounters.csv data/raw/organizations.csv data/raw/payers.csv

.PHONY: help check-data start wait schema load view setup quality analysis export status stop reset

help:
	@printf '%s\n' \
	  'make setup     Start PostgreSQL, create tables, load CSVs, and build the view' \
	  'make quality   Run the data-quality report' \
	  'make analysis  Run the five KPI queries' \
	  'make export    Create data/processed/encounter_analysis.csv for Tableau' \
	  'make status    Show row counts and the encounter date range' \
	  'make stop      Stop PostgreSQL without deleting data' \
	  'make reset     Stop PostgreSQL and delete the local database volume'

check-data:
	@for file in $(RAW_FILES); do \
	  if [ ! -f "$$file" ]; then \
	    echo "Missing $$file"; \
	    echo "Place all four Synthea CSV files in data/raw/ and run make setup again."; \
	    exit 1; \
	  fi; \
	done
	@echo "Found all four required CSV files."

start:
	$(COMPOSE) up -d

wait: start
	@until $(COMPOSE) exec -T postgres pg_isready -U synthea -d synthea >/dev/null 2>&1; do \
	  echo "Waiting for PostgreSQL..."; \
	  sleep 2; \
	done
	@echo "PostgreSQL is ready."

schema: wait
	$(PSQL) -f - < sql/01_create_tables.sql

load: check-data schema
	$(PSQL) -f - < sql/02_load_data.sql

view: load
	$(PSQL) -f - < sql/03_analysis_view.sql

setup: view
	@echo "Setup complete. Next run: make quality"

quality:
	$(PSQL) -f - < sql/05_data_quality.sql

analysis:
	$(PSQL) -f - < sql/04_kpi_queries.sql

export:
	@mkdir -p data/processed
	@$(COMPOSE) exec -T postgres \
	  psql -U synthea -d synthea -v ON_ERROR_STOP=1 \
	  --csv -P footer=off -q -f - \
	  < sql/06_tableau_export.sql \
	  > data/processed/encounter_analysis.csv
	@echo "Created data/processed/encounter_analysis.csv"

status:
	@$(PSQL) -c "SELECT 'patients' AS table_name, COUNT(*) AS row_count FROM raw.patients UNION ALL SELECT 'encounters', COUNT(*) FROM raw.encounters UNION ALL SELECT 'organizations', COUNT(*) FROM raw.organizations UNION ALL SELECT 'payers', COUNT(*) FROM raw.payers ORDER BY table_name;"
	@$(PSQL) -c "SELECT MIN(start_time)::date AS first_encounter, MAX(start_time)::date AS last_encounter, COUNT(*) AS encounter_count FROM analytics.vw_encounter_analysis;"

stop:
	$(COMPOSE) down

reset:
	$(COMPOSE) down -v
