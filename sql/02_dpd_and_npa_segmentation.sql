-- Base Risk Features

CREATE OR REPLACE VIEW view_credit_risk_base AS
SELECT
    client_id,
    person_age,
    person_income,
    person_emp_length,
    person_home_ownership,
    loan_amnt,
    loan_intent,
    loan_grade,
    loan_int_rate,
    loan_status,
    loan_percent_income,
    loan_to_income_ratio,
    other_debt,
    debt_to_income_ratio,
    open_accounts,
    credit_utilization_ratio,
    cb_person_default_on_file,
    cb_person_cred_hist_length,
    past_delinquencies,
    country,
    state,
    city,
    city_latitude,
    city_longitude,
    CASE
        WHEN loan_status = 1 THEN 1
        ELSE 0
    END AS default_flag,
    CASE
        WHEN UPPER(BTRIM(cb_person_default_on_file)) = 'Y'
          OR COALESCE(past_delinquencies, 0) > 0
        THEN 1
        ELSE 0
    END AS prior_delinquency_flag,
    CASE
        WHEN loan_percent_income IS NULL THEN 'Unknown'
        WHEN loan_percent_income < 0.10 THEN '<10%'
        WHEN loan_percent_income < 0.20 THEN '10%-20%'
        WHEN loan_percent_income < 0.30 THEN '20%-30%'
        WHEN loan_percent_income < 0.35 THEN '30%-35%'
        WHEN loan_percent_income < 0.40 THEN '35%-40%'
        ELSE '40%+'
    END AS dti_proxy_band
FROM credit_risk_clean;

-- Master Credit Risk Analytics View

CREATE OR REPLACE VIEW view_credit_risk_analytics AS
WITH enriched AS (
    SELECT
        b.*,
        COUNT(*) OVER (PARTITION BY loan_grade) AS grade_loan_count,
        SUM(loan_amnt) OVER (PARTITION BY loan_grade) AS grade_total_exposure,
        SUM(loan_amnt) FILTER (WHERE default_flag = 1)
            OVER (PARTITION BY loan_grade) AS grade_default_exposure,
        AVG(default_flag::NUMERIC) OVER (PARTITION BY loan_grade) * 100.0
            AS grade_default_rate_pct,
        AVG(loan_int_rate) OVER (PARTITION BY loan_grade)
            AS grade_avg_interest_rate_pct,
        AVG(loan_percent_income) OVER (PARTITION BY loan_grade) * 100.0
            AS grade_avg_loan_income_pct,
        COUNT(*) OVER () AS portfolio_loan_count,
        SUM(loan_amnt) OVER () AS portfolio_total_exposure,
        SUM(loan_amnt) FILTER (WHERE default_flag = 1) OVER ()
            AS portfolio_default_exposure
    FROM view_credit_risk_base b
)
SELECT
    e.*,
    e.grade_default_rate_pct / 100.0 AS segment_pd_proxy,
    e.loan_amnt
        * (e.grade_default_rate_pct / 100.0)
        * 0.45 AS expected_loss_proxy,
    CASE
        WHEN e.portfolio_default_exposure = 0 THEN 0
        ELSE 100.0 * e.grade_default_exposure
            / e.portfolio_default_exposure
    END AS grade_share_of_default_exposure_pct
FROM enriched e;

-- Loan Grade Risk Summary

CREATE OR REPLACE VIEW view_credit_grade_summary AS
SELECT
    loan_grade,
    COUNT(*) AS loan_count,
    SUM(loan_amnt) AS total_loan_exposure,
    SUM(loan_amnt) FILTER (WHERE default_flag = 1) AS default_exposure,
    ROUND(100.0 * AVG(default_flag::NUMERIC), 2) AS default_rate_pct,
    ROUND(
        100.0 * SUM(loan_amnt) FILTER (WHERE default_flag = 1)
        / NULLIF(SUM(loan_amnt), 0),
        2
    ) AS gross_npa_proxy_pct,
    ROUND(AVG(loan_int_rate), 2) AS avg_interest_rate_pct,
    ROUND(100.0 * AVG(loan_percent_income), 2) AS avg_loan_income_pct,
    ROUND(
        SUM(loan_amnt)
        * AVG(default_flag::NUMERIC)
        * 0.45,
        2
    ) AS expected_loss_proxy
FROM view_credit_risk_base
GROUP BY loan_grade;

-- Loan Intent Risk Summary

CREATE OR REPLACE VIEW view_credit_intent_summary AS
SELECT
    loan_intent,
    COUNT(*) AS loan_count,
    SUM(loan_amnt) AS total_loan_exposure,
    SUM(loan_amnt) FILTER (WHERE default_flag = 1) AS default_exposure,
    ROUND(100.0 * AVG(default_flag::NUMERIC), 2) AS default_rate_pct,
    ROUND(
        100.0 * SUM(loan_amnt) FILTER (WHERE default_flag = 1)
        / NULLIF(SUM(loan_amnt), 0),
        2
    ) AS gross_npa_proxy_pct,
    ROUND(AVG(loan_int_rate), 2) AS avg_interest_rate_pct,
    ROUND(100.0 * AVG(loan_percent_income), 2) AS avg_loan_income_pct,
    ROUND(
        SUM(loan_amnt)
        * AVG(default_flag::NUMERIC)
        * 0.45,
        2
    ) AS expected_loss_proxy
FROM view_credit_risk_base
GROUP BY loan_intent;

-- DTI-Proxy Risk Summary

CREATE OR REPLACE VIEW view_dti_risk_summary AS
SELECT
    dti_proxy_band,
    COUNT(*) AS loan_count,
    SUM(loan_amnt) AS total_loan_exposure,
    SUM(loan_amnt) FILTER (WHERE default_flag = 1) AS default_exposure,
    ROUND(100.0 * AVG(default_flag::NUMERIC), 2) AS default_rate_pct,
    ROUND(AVG(loan_int_rate), 2) AS avg_interest_rate_pct,
    ROUND(100.0 * AVG(loan_percent_income), 2) AS avg_loan_income_pct,
    ROUND(
        SUM(loan_amnt)
        * AVG(default_flag::NUMERIC)
        * 0.45,
        2
    ) AS expected_loss_proxy
FROM view_credit_risk_base
GROUP BY dti_proxy_band;

-- Prior Delinquency + Interest Rate Analysis

CREATE OR REPLACE VIEW view_history_interest_rate_risk AS
WITH risk_bands AS (
    SELECT
        prior_delinquency_flag,
        CASE
            WHEN loan_int_rate IS NULL THEN 'Unknown'
            WHEN loan_int_rate < 10 THEN '<10%'
            WHEN loan_int_rate < 15 THEN '10%-15%'
            WHEN loan_int_rate < 20 THEN '15%-20%'
            ELSE '20%+'
        END AS interest_rate_band,
        default_flag,
        loan_amnt
    FROM view_credit_risk_base
)
SELECT
    prior_delinquency_flag,
    interest_rate_band,
    COUNT(*) AS loan_count,
    ROUND(100.0 * AVG(default_flag::NUMERIC), 2) AS default_rate_pct,
    SUM(loan_amnt) AS total_loan_exposure,
    SUM(loan_amnt) FILTER (WHERE default_flag = 1) AS default_exposure
FROM risk_bands
GROUP BY prior_delinquency_flag, interest_rate_band;

-- Delinquency History -> Current Outcome Transition Proxy

CREATE OR REPLACE VIEW view_delinquency_transition_proxy AS
WITH transition_counts AS (
    SELECT
        loan_grade,
        CASE
            WHEN prior_delinquency_flag = 1
                THEN 'Prior Delinquency / Default'
            ELSE 'No Prior Delinquency / Default'
        END AS prior_risk_state,
        CASE
            WHEN default_flag = 1 THEN 'Current Default'
            ELSE 'Current Non-Default'
        END AS current_risk_state,
        COUNT(*) AS loan_count
    FROM view_credit_risk_base
    GROUP BY
        loan_grade,
        prior_risk_state,
        current_risk_state
)
SELECT
    loan_grade,
    prior_risk_state,
    current_risk_state,
    loan_count,
    ROUND(
        100.0 * loan_count
        / SUM(loan_count) OVER (
            PARTITION BY loan_grade, prior_risk_state
        ),
        2
    ) AS transition_rate_pct
FROM transition_counts;

-- Final Review

SELECT
    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_loan_exposure,
    COUNT(*) FILTER (WHERE default_flag = 1) AS total_defaults,
    ROUND(100.0 * AVG(default_flag::NUMERIC), 2) AS default_rate_pct,
    ROUND(
        100.0 * SUM(loan_amnt) FILTER (WHERE default_flag = 1)
        / NULLIF(SUM(loan_amnt), 0),
        2
    ) AS gross_npa_proxy_pct,
    ROUND(AVG(loan_int_rate), 2) AS avg_interest_rate_pct,
    ROUND(100.0 * AVG(loan_percent_income), 2) AS avg_loan_income_pct
FROM view_credit_risk_base;

SELECT *
FROM view_credit_grade_summary
ORDER BY
    CASE loan_grade
        WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3
        WHEN 'D' THEN 4 WHEN 'E' THEN 5 WHEN 'F' THEN 6
        WHEN 'G' THEN 7 ELSE 8
    END;

SELECT *
FROM view_credit_intent_summary
ORDER BY default_rate_pct DESC;

SELECT *
FROM view_dti_risk_summary
ORDER BY
    CASE dti_proxy_band
        WHEN '<10%' THEN 1
        WHEN '10%-20%' THEN 2
        WHEN '20%-30%' THEN 3
        WHEN '30%-35%' THEN 4
        WHEN '35%-40%' THEN 5
        WHEN '40%+' THEN 6
        ELSE 7
    END;

SELECT *
FROM view_history_interest_rate_risk
ORDER BY prior_delinquency_flag, interest_rate_band;

SELECT *
FROM view_delinquency_transition_proxy
ORDER BY
    CASE loan_grade
        WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3
        WHEN 'D' THEN 4 WHEN 'E' THEN 5 WHEN 'F' THEN 6
        WHEN 'G' THEN 7 ELSE 8
    END,
    prior_risk_state,
    current_risk_state;

SELECT *
FROM view_credit_risk_analytics
LIMIT 20;