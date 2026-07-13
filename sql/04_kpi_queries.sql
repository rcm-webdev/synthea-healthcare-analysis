-- KPI 1: Monthly encounter and patient volume with month-over-month change.
WITH monthly_volume AS (
    SELECT
        encounter_month,
        COUNT(*) AS encounter_count,
        COUNT(DISTINCT patient_id) AS distinct_patient_count
    FROM analytics.vw_encounter_analysis
    GROUP BY encounter_month
)
SELECT
    encounter_month,
    encounter_count,
    distinct_patient_count,
    encounter_count
        - LAG(encounter_count) OVER (ORDER BY encounter_month)
        AS encounter_change_from_prior_month
FROM monthly_volume
ORDER BY encounter_month;

-- KPI 2: Overall claim-cost profile.
SELECT
    COUNT(*) AS encounter_count,
    ROUND(SUM(total_claim_cost), 2) AS total_claim_cost,
    ROUND(AVG(total_claim_cost), 2) AS average_claim_cost_per_encounter,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_claim_cost)::NUMERIC, 2)
        AS median_claim_cost_per_encounter,
    ROUND(SUM(patient_responsibility), 2) AS total_patient_responsibility
FROM analytics.vw_encounter_analysis;

-- KPI 3: Payer coverage by payer, weighted by total claim cost.
SELECT
    payer_name,
    COUNT(*) AS encounter_count,
    ROUND(SUM(total_claim_cost), 2) AS total_claim_cost,
    ROUND(SUM(payer_coverage), 2) AS total_payer_coverage,
    ROUND(
        100.0 * SUM(payer_coverage) / NULLIF(SUM(total_claim_cost), 0),
        2
    ) AS payer_coverage_percent
FROM analytics.vw_encounter_analysis
GROUP BY payer_name
ORDER BY total_claim_cost DESC;

-- KPI 4: Encounter-class mix as count and percentage of all encounters.
WITH encounter_class_counts AS (
    SELECT
        COALESCE(encounter_class, 'Unknown') AS encounter_class,
        COUNT(*) AS encounter_count
    FROM analytics.vw_encounter_analysis
    GROUP BY COALESCE(encounter_class, 'Unknown')
)
SELECT
    encounter_class,
    encounter_count,
    ROUND(
        100.0 * encounter_count / NULLIF(SUM(encounter_count) OVER (), 0),
        2
    ) AS encounter_percent
FROM encounter_class_counts
ORDER BY encounter_count DESC;

-- KPI 5: Organization activity and cost ranking.
WITH organization_metrics AS (
    SELECT
        organization_name,
        organization_city,
        organization_state,
        COUNT(*) AS encounter_count,
        COUNT(DISTINCT patient_id) AS distinct_patient_count,
        SUM(total_claim_cost) AS total_claim_cost,
        AVG(total_claim_cost) AS average_claim_cost
    FROM analytics.vw_encounter_analysis
    GROUP BY organization_name, organization_city, organization_state
)
SELECT
    DENSE_RANK() OVER (ORDER BY encounter_count DESC) AS encounter_rank,
    organization_name,
    organization_city,
    organization_state,
    encounter_count,
    distinct_patient_count,
    ROUND(total_claim_cost, 2) AS total_claim_cost,
    ROUND(average_claim_cost, 2) AS average_claim_cost
FROM organization_metrics
ORDER BY encounter_rank, organization_name
LIMIT 20;
