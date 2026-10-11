-- Age Cohort Risk 

SELECT
    CASE
        WHEN person_age < 25 THEN '<25'
        WHEN person_age < 35 THEN '25-34'
        WHEN person_age < 45 THEN '35-44'
        WHEN person_age < 55 THEN '45-54'
        ELSE '55+'
    END AS age_cohort,

    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_exposure,
    SUM(loan_status) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS default_rate_pct
FROM credit_risk_clean
GROUP BY
    CASE
        WHEN person_age < 25 THEN '<25'
        WHEN person_age < 35 THEN '25-34'
        WHEN person_age < 45 THEN '35-44'
        WHEN person_age < 55 THEN '45-54'
        ELSE '55+'
    END
ORDER BY
    age_cohort;

-- Income Cohort Risk

SELECT
    CASE
        WHEN person_income < 25000 THEN '<25K'
        WHEN person_income < 50000 THEN '25K-50K'
        WHEN person_income < 100000 THEN '50K-100K'
        WHEN person_income < 200000 THEN '100K-200K'
        ELSE '200K+'
    END AS income_cohort,

    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_exposure,
    SUM(loan_status) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS default_rate_pct
FROM credit_risk_clean
GROUP BY
    CASE
        WHEN person_income < 25000 THEN '<25K'
        WHEN person_income < 50000 THEN '25K-50K'
        WHEN person_income < 100000 THEN '50K-100K'
        WHEN person_income < 200000 THEN '100K-200K'
        ELSE '200K+'
    END
ORDER BY
    income_cohort;

-- Loan Amount Cohort Risk

SELECT
    CASE
        WHEN loan_amnt < 5000 THEN '<5K'
        WHEN loan_amnt < 10000 THEN '5K-10K'
        WHEN loan_amnt < 20000 THEN '10K-20K'
        WHEN loan_amnt < 30000 THEN '20K-30K'
        ELSE '30K+'
    END AS loan_amount_cohort,

    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_exposure,
    SUM(loan_status) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS default_rate_pct
FROM credit_risk_clean
GROUP BY
    CASE
        WHEN loan_amnt < 5000 THEN '<5K'
        WHEN loan_amnt < 10000 THEN '5K-10K'
        WHEN loan_amnt < 20000 THEN '10K-20K'
        WHEN loan_amnt < 30000 THEN '20K-30K'
        ELSE '30K+'
    END
ORDER BY
    loan_amount_cohort;

-- Credit History Cohort Risk

SELECT
    CASE
        WHEN cb_person_cred_hist_length < 3 THEN '<3 Years'
        WHEN cb_person_cred_hist_length < 5 THEN '3-4 Years'
        WHEN cb_person_cred_hist_length < 7 THEN '5-6 Years'
        WHEN cb_person_cred_hist_length < 10 THEN '7-9 Years'
        ELSE '10+ Years'
    END AS credit_history_cohort,

    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_exposure,
    SUM(loan_status) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS default_rate_pct
FROM credit_risk_clean
GROUP BY
    CASE
        WHEN cb_person_cred_hist_length < 3 THEN '<3 Years'
        WHEN cb_person_cred_hist_length < 5 THEN '3-4 Years'
        WHEN cb_person_cred_hist_length < 7 THEN '5-6 Years'
        WHEN cb_person_cred_hist_length < 10 THEN '7-9 Years'
        ELSE '10+ Years'
    END
ORDER BY
    credit_history_cohort;

-- DTI x Credit Grade Risk Cohorts

SELECT
    loan_grade,

    CASE
        WHEN debt_to_income_ratio < 0.20 THEN '<20%'
        WHEN debt_to_income_ratio < 0.30 THEN '20%-30%'
        WHEN debt_to_income_ratio < 0.40 THEN '30%-40%'
        ELSE '40%+'
    END AS dti_cohort,

    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_exposure,
    SUM(loan_status) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS default_rate_pct
FROM credit_risk_clean
GROUP BY
    loan_grade,
    CASE
        WHEN debt_to_income_ratio < 0.20 THEN '<20%'
        WHEN debt_to_income_ratio < 0.30 THEN '20%-30%'
        WHEN debt_to_income_ratio < 0.40 THEN '30%-40%'
        ELSE '40%+'
    END
ORDER BY
    loan_grade,
    dti_cohort;

-- Risk Cohort Summary

SELECT
    loan_grade,
    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_exposure,
    SUM(loan_status) AS current_defaults,

    ROUND(
        AVG(loan_status) * 100,
        2
    ) AS default_rate_pct,

    ROUND(
        AVG(debt_to_income_ratio) * 100,
        2
    ) AS avg_dti_pct,

    ROUND(
        AVG(loan_int_rate),
        2
    ) AS avg_interest_rate_pct
FROM credit_risk_clean
GROUP BY
    loan_grade
ORDER BY
    loan_grade;

