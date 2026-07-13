WITH quality_checks AS (
    SELECT
        'Duplicate encounter IDs' AS check_name,
        COUNT(*)::BIGINT AS issue_count
    FROM (
        SELECT id
        FROM raw.encounters
        GROUP BY id
        HAVING COUNT(*) > 1
    ) AS duplicate_ids

    UNION ALL

    SELECT
        'Missing encounter date or patient ID',
        COUNT(*)
    FROM raw.encounters
    WHERE start_time IS NULL
       OR patient_id IS NULL

    UNION ALL

    SELECT
        'Unmatched patient IDs',
        COUNT(*)
    FROM raw.encounters AS e
    LEFT JOIN raw.patients AS p
        ON e.patient_id = p.id
    WHERE p.id IS NULL

    UNION ALL

    SELECT
        'Unmatched organization IDs',
        COUNT(*)
    FROM raw.encounters AS e
    LEFT JOIN raw.organizations AS o
        ON e.organization_id = o.id
    WHERE e.organization_id IS NOT NULL
      AND o.id IS NULL

    UNION ALL

    SELECT
        'Unmatched payer IDs',
        COUNT(*)
    FROM raw.encounters AS e
    LEFT JOIN raw.payers AS p
        ON e.payer_id = p.id
    WHERE e.payer_id IS NOT NULL
      AND p.id IS NULL

    UNION ALL

    SELECT
        'Negative cost values',
        COUNT(*)
    FROM raw.encounters
    WHERE base_encounter_cost < 0
       OR total_claim_cost < 0
       OR payer_coverage < 0

    UNION ALL

    SELECT
        'Payer coverage exceeds total claim cost',
        COUNT(*)
    FROM raw.encounters
    WHERE payer_coverage > total_claim_cost

    UNION ALL

    SELECT
        'Encounter stop precedes start',
        COUNT(*)
    FROM raw.encounters
    WHERE stop_time < start_time
)
SELECT
    check_name,
    issue_count,
    CASE
        WHEN issue_count = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS status
FROM quality_checks
ORDER BY
    CASE WHEN issue_count = 0 THEN 1 ELSE 0 END,
    issue_count DESC,
    check_name;
