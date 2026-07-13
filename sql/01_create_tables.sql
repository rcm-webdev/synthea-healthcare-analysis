DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;

CREATE SCHEMA raw;
CREATE SCHEMA analytics;

CREATE TABLE raw.patients (
    id                    UUID PRIMARY KEY,
    birthdate             DATE NOT NULL,
    deathdate             DATE,
    ssn                   TEXT,
    drivers               TEXT,
    passport              TEXT,
    prefix                TEXT,
    first_name            TEXT,
    last_name             TEXT,
    suffix                TEXT,
    maiden                TEXT,
    marital               TEXT,
    race                  TEXT,
    ethnicity             TEXT,
    gender                TEXT,
    birthplace            TEXT,
    address               TEXT,
    city                  TEXT,
    state                 TEXT,
    county                TEXT,
    zip                   TEXT,
    lat                   NUMERIC(10, 7),
    lon                   NUMERIC(10, 7),
    healthcare_expenses   NUMERIC(14, 2),
    healthcare_coverage   NUMERIC(14, 2)
);

CREATE TABLE raw.organizations (
    id            UUID PRIMARY KEY,
    name          TEXT NOT NULL,
    address       TEXT,
    city          TEXT,
    state         TEXT,
    zip           TEXT,
    lat           NUMERIC(10, 7),
    lon           NUMERIC(10, 7),
    phone         TEXT,
    revenue       NUMERIC(16, 2),
    utilization   INTEGER
);

CREATE TABLE raw.payers (
    id                       UUID PRIMARY KEY,
    name                     TEXT NOT NULL,
    address                  TEXT,
    city                     TEXT,
    state_headquartered      TEXT,
    zip                      TEXT,
    phone                    TEXT,
    amount_covered           NUMERIC(16, 2),
    amount_uncovered         NUMERIC(16, 2),
    revenue                  NUMERIC(16, 2),
    covered_encounters       INTEGER,
    uncovered_encounters     INTEGER,
    covered_medications      INTEGER,
    uncovered_medications    INTEGER,
    covered_procedures       INTEGER,
    uncovered_procedures     INTEGER,
    covered_immunizations    INTEGER,
    uncovered_immunizations  INTEGER,
    unique_customers         INTEGER,
    qols_avg                 NUMERIC(12, 6),
    member_months            INTEGER
);

CREATE TABLE raw.encounters (
    id                    UUID PRIMARY KEY,
    start_time            TIMESTAMPTZ NOT NULL,
    stop_time             TIMESTAMPTZ,
    patient_id            UUID NOT NULL,
    organization_id       UUID,
    provider_id           UUID,
    payer_id              UUID,
    encounter_class       TEXT,
    code                  TEXT,
    description           TEXT,
    base_encounter_cost   NUMERIC(14, 2),
    total_claim_cost      NUMERIC(14, 2),
    payer_coverage        NUMERIC(14, 2),
    reason_code           TEXT,
    reason_description    TEXT
);

-- Index the join and filter columns used by the analysis.
CREATE INDEX idx_encounters_patient_id
    ON raw.encounters (patient_id);

CREATE INDEX idx_encounters_organization_id
    ON raw.encounters (organization_id);

CREATE INDEX idx_encounters_payer_id
    ON raw.encounters (payer_id);

CREATE INDEX idx_encounters_start_time
    ON raw.encounters (start_time);

COMMENT ON SCHEMA raw IS
    'Source-aligned Synthea CSV tables used for healthcare analysis.';

COMMENT ON SCHEMA analytics IS
    'Reusable analytical views and exported reporting datasets.';
