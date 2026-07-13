\set ON_ERROR_STOP on
\echo 'Loading the four Synthea CSV files from /data/raw ...'

BEGIN;

TRUNCATE TABLE
    raw.encounters,
    raw.patients,
    raw.organizations,
    raw.payers;

-- psql requires each \copy meta-command to remain on one physical line.
\copy raw.patients (id, birthdate, deathdate, ssn, drivers, passport, prefix, first_name, last_name, suffix, maiden, marital, race, ethnicity, gender, birthplace, address, city, state, county, zip, lat, lon, healthcare_expenses, healthcare_coverage) FROM '/data/raw/patients.csv' WITH (FORMAT CSV, HEADER TRUE, NULL '', ENCODING 'UTF8');

\copy raw.organizations (id, name, address, city, state, zip, lat, lon, phone, revenue, utilization) FROM '/data/raw/organizations.csv' WITH (FORMAT CSV, HEADER TRUE, NULL '', ENCODING 'UTF8');

\copy raw.payers (id, name, address, city, state_headquartered, zip, phone, amount_covered, amount_uncovered, revenue, covered_encounters, uncovered_encounters, covered_medications, uncovered_medications, covered_procedures, uncovered_procedures, covered_immunizations, uncovered_immunizations, unique_customers, qols_avg, member_months) FROM '/data/raw/payers.csv' WITH (FORMAT CSV, HEADER TRUE, NULL '', ENCODING 'UTF8');

\copy raw.encounters (id, start_time, stop_time, patient_id, organization_id, provider_id, payer_id, encounter_class, code, description, base_encounter_cost, total_claim_cost, payer_coverage, reason_code, reason_description) FROM '/data/raw/encounters.csv' WITH (FORMAT CSV, HEADER TRUE, NULL '', ENCODING 'UTF8');

COMMIT;

\echo 'Load complete. Row counts:'
SELECT 'patients' AS table_name, COUNT(*) AS row_count FROM raw.patients
UNION ALL
SELECT 'encounters', COUNT(*) FROM raw.encounters
UNION ALL
SELECT 'organizations', COUNT(*) FROM raw.organizations
UNION ALL
SELECT 'payers', COUNT(*) FROM raw.payers
ORDER BY table_name;
