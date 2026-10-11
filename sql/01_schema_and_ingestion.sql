-- Raw Table

CREATE TABLE credit_risk_raw (
    client_id TEXT,
    person_age INT,
    person_income NUMERIC,
    person_home_ownership TEXT,
    person_emp_length NUMERIC,
    loan_intent TEXT,
    loan_grade TEXT,
    loan_amnt NUMERIC,
    loan_int_rate NUMERIC,
    loan_status INT,
    loan_percent_income NUMERIC,
    cb_person_default_on_file TEXT,
    cb_person_cred_hist_length INT,
    gender TEXT,
    marital_status TEXT,
    education_level TEXT,
    country TEXT,
    state TEXT,
    city TEXT,
    city_latitude NUMERIC,
    city_longitude NUMERIC,
    employment_type TEXT,
    loan_term_months INT,
    loan_to_income_ratio NUMERIC,
    other_debt NUMERIC,
    debt_to_income_ratio NUMERIC,
    open_accounts INT,
    credit_utilization_ratio NUMERIC,
    past_delinquencies INT
);

-- Raw Data Validation

SELECT
    COUNT(*) AS total_loans,
    COUNT(DISTINCT client_id) AS unique_clients
FROM credit_risk_raw;

SELECT
    COUNT(*) AS duplicate_client_ids
FROM (
    SELECT client_id
    FROM credit_risk_raw
    GROUP BY client_id
    HAVING COUNT(*) > 1
) AS duplicates;

SELECT
    loan_status,
    COUNT(*) AS loan_count
FROM credit_risk_raw
GROUP BY loan_status
ORDER BY loan_status;

SELECT
    loan_grade,
    COUNT(*) AS loan_count
FROM credit_risk_raw
GROUP BY loan_grade
ORDER BY loan_grade;


SELECT COUNT(*) AS invalid_age_count
FROM credit_risk_raw
WHERE person_age NOT BETWEEN 18 AND 100;

SELECT COUNT(*) AS invalid_emp_length_count
FROM credit_risk_raw
WHERE person_emp_length < 0
   OR person_emp_length > 70;

SELECT
    client_id,
    person_age,
    loan_status,
    loan_grade
FROM credit_risk_raw
WHERE person_age NOT BETWEEN 18 AND 100;

SELECT
    client_id,
    person_emp_length,
    person_age,
    loan_grade
FROM credit_risk_raw
WHERE person_emp_length < 0
   OR person_emp_length > 70;

-- Clean Table

CREATE TABLE credit_risk_clean AS
SELECT *
FROM credit_risk_raw;

-- Data Cleaning

UPDATE credit_risk_clean
SET person_age = NULL
WHERE person_age < 18
   OR person_age > 100;

UPDATE credit_risk_clean
SET person_age = (
    SELECT PERCENTILE_CONT(0.5)
           WITHIN GROUP (ORDER BY person_age)
    FROM credit_risk_clean
    WHERE person_age IS NOT NULL
)
WHERE person_age IS NULL;


UPDATE credit_risk_clean
SET person_emp_length = NULL
WHERE person_emp_length < 0
   OR person_emp_length > 70;

UPDATE credit_risk_clean
SET person_emp_length = (
    SELECT PERCENTILE_CONT(0.5)
           WITHIN GROUP (ORDER BY person_emp_length)
    FROM credit_risk_clean
    WHERE person_emp_length IS NOT NULL
)
WHERE person_emp_length IS NULL;

UPDATE credit_risk_clean c
SET loan_int_rate = r.avg_rate
FROM (
    SELECT
        loan_grade,
        AVG(loan_int_rate) AS avg_rate
    FROM credit_risk_clean
    WHERE loan_int_rate IS NOT NULL
    GROUP BY loan_grade
) r
WHERE c.loan_grade = r.loan_grade
  AND c.loan_int_rate IS NULL;

-- Primary Key

ALTER TABLE credit_risk_clean
ADD CONSTRAINT pk_credit_risk_client
PRIMARY KEY (client_id);

-- Indexes


CREATE INDEX idx_credit_risk_grade
ON credit_risk_clean (loan_grade);


CREATE INDEX idx_credit_risk_status
ON credit_risk_clean (loan_status);

-- Final Validation

SELECT
    COUNT(*) AS total_loans,
    COUNT(DISTINCT client_id) AS unique_clients,
    SUM(loan_status) AS defaults,
    ROUND(AVG(loan_status) * 100, 2) AS default_rate
FROM credit_risk_clean;

SELECT COUNT(*) AS invalid_age_count
FROM credit_risk_clean
WHERE person_age < 18
   OR person_age > 100;

SELECT COUNT(*) AS invalid_emp_length_count
FROM credit_risk_clean
WHERE person_emp_length < 0
   OR person_emp_length > 70;

SELECT COUNT(*) AS missing_emp_length
FROM credit_risk_clean
WHERE person_emp_length IS NULL;

SELECT COUNT(*) AS missing_interest_rate
FROM credit_risk_clean
WHERE loan_int_rate IS NULL;

