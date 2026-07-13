DROP VIEW IF EXISTS analytics.vw_encounter_analysis;

CREATE VIEW analytics.vw_encounter_analysis AS
WITH encounter_base AS (
    SELECT
        e.id AS encounter_id,
        e.start_time,
        e.stop_time,
        DATE_TRUNC('month', e.start_time)::DATE AS encounter_month,
        EXTRACT(YEAR FROM e.start_time)::INTEGER AS encounter_year,
        e.encounter_class,
        e.description AS encounter_description,
        e.patient_id,
        e.organization_id,
        e.payer_id,
        e.base_encounter_cost,
        e.total_claim_cost,
        e.payer_coverage,
        e.total_claim_cost - COALESCE(e.payer_coverage, 0) AS patient_responsibility,
        e.payer_coverage / NULLIF(e.total_claim_cost, 0) AS payer_coverage_rate,
        EXTRACT(EPOCH FROM (e.stop_time - e.start_time)) / 3600.0
            AS encounter_duration_hours
    FROM raw.encounters AS e
)
SELECT
    eb.encounter_id,
    eb.start_time,
    eb.stop_time,
    eb.encounter_month,
    eb.encounter_year,
    eb.encounter_class,
    eb.encounter_description,
    eb.patient_id,
    p.gender AS patient_gender,
    p.race AS patient_race,
    p.ethnicity AS patient_ethnicity,
    EXTRACT(YEAR FROM AGE(eb.start_time::DATE, p.birthdate))::INTEGER
        AS patient_age_at_encounter,
    eb.organization_id,
    COALESCE(o.name, 'Unmatched organization') AS organization_name,
    o.city AS organization_city,
    o.state AS organization_state,
    eb.payer_id,
    COALESCE(py.name, 'No matched payer') AS payer_name,
    eb.base_encounter_cost,
    eb.total_claim_cost,
    eb.payer_coverage,
    eb.patient_responsibility,
    eb.payer_coverage_rate,
    eb.encounter_duration_hours,
    p.id IS NOT NULL AS patient_matched,
    o.id IS NOT NULL AS organization_matched,
    py.id IS NOT NULL AS payer_matched
FROM encounter_base AS eb
LEFT JOIN raw.patients AS p
    ON eb.patient_id = p.id
LEFT JOIN raw.organizations AS o
    ON eb.organization_id = o.id
LEFT JOIN raw.payers AS py
    ON eb.payer_id = py.id;

COMMENT ON VIEW analytics.vw_encounter_analysis IS
    'One row per Synthea encounter with patient, organization, payer, cost, and quality-assurance fields for analysis and Tableau.';
