-- Overall Delinquency Migration Matrix

WITH risk_transition AS (
    SELECT
        CASE
            WHEN cb_person_default_on_file = 'Y'
                THEN 'Historical Default On File'
            ELSE 'No Historical Default On File'
        END AS historical_risk_state,

        CASE
            WHEN loan_status = 1
                THEN 'Current Loan Default'
            ELSE 'Current Loan Non-Default'
        END AS current_risk_state

    FROM credit_risk_clean)
SELECT
    historical_risk_state,
    current_risk_state,
    COUNT(*) AS loan_count,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY historical_risk_state),
        2
    ) AS transition_rate_pct
FROM risk_transition
GROUP BY
    historical_risk_state,
    current_risk_state
ORDER BY
    historical_risk_state,
    current_risk_state;

-- Delinquency Migration By Credit Grade

WITH grade_transition AS (
    SELECT
        loan_grade,

        CASE
            WHEN cb_person_default_on_file = 'Y'
                THEN 'Historical Default On File'
            ELSE 'No Historical Default On File'
        END AS historical_risk_state,

        CASE
            WHEN loan_status = 1
                THEN 'Current Loan Default'
            ELSE 'Current Loan Non-Default'
        END AS current_risk_state

    FROM credit_risk_clean)
SELECT
    loan_grade,
    historical_risk_state,
    current_risk_state,
    COUNT(*) AS loan_count,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (
            PARTITION BY loan_grade, historical_risk_state
        ),
        2
    ) AS transition_rate_pct
FROM grade_transition
GROUP BY
    loan_grade,
    historical_risk_state,
    current_risk_state
ORDER BY
    loan_grade,
    historical_risk_state,
    current_risk_state;

-- Current Loan Default Rate By Prior Risk State And Grade

SELECT
    loan_grade,
    COUNT(*) AS total_loans,
    SUM(
        CASE
            WHEN cb_person_default_on_file = 'Y'
                THEN 1
            ELSE 0
        END
    ) AS prior_default_loans,
    SUM(
        CASE
            WHEN cb_person_default_on_file = 'Y'
                 AND loan_status = 1
                THEN 1
            ELSE 0
        END
    ) AS prior_default_current_default,
    ROUND(
        SUM(
            CASE
                WHEN cb_person_default_on_file = 'Y'
                     AND loan_status = 1
                    THEN 1
                ELSE 0
            END
        ) * 100.0
        / NULLIF(
            SUM(
                CASE
                    WHEN cb_person_default_on_file = 'Y'
                        THEN 1
                    ELSE 0
                END),0),2
    ) AS prior_default_current_default_rate_pct
FROM credit_risk_clean
GROUP BY
    loan_grade
ORDER BY
    loan_grade;

-- Default Rate Change Associated With Historical Default On File Status

WITH grade_default_rates AS (
    SELECT
        loan_grade,

        AVG(
            CASE
                WHEN cb_person_default_on_file = 'Y'
                    THEN loan_status
            END
        ) * 100 AS prior_default_rate,

        AVG(
            CASE
                WHEN cb_person_default_on_file = 'N'
                    THEN loan_status
            END
        ) * 100 AS no_prior_default_rate

    FROM credit_risk_clean
    GROUP BY
        loan_grade
)
SELECT
    loan_grade,
    ROUND(prior_default_rate, 2) AS prior_default_rate_pct,
    ROUND(no_prior_default_rate, 2) AS no_prior_default_rate_pct,
    ROUND(
        prior_default_rate - no_prior_default_rate,
        2
    ) AS default_rate_difference_pct
FROM grade_default_rates
ORDER BY
    loan_grade;

-- Delinquency Migration Summary

SELECT
    CASE
        WHEN cb_person_default_on_file = 'Y'
            THEN 'Historical Default On File'
        ELSE 'No Historical Default On File'
    END AS historical_risk_state,

    COUNT(*) AS total_loans,

    SUM(
        CASE
            WHEN loan_status = 1
                THEN 1
            ELSE 0
        END
    ) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS current_default_rate_pct
FROM credit_risk_clean
GROUP BY
    CASE
        WHEN cb_person_default_on_file = 'Y'
            THEN 'Historical Default On File'
        ELSE 'No Historical Default On File'
    END
ORDER BY
    historical_risk_state;