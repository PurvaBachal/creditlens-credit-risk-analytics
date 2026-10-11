# CreditLens — Credit Risk & Default Analysis

# Project links

**Tableau Public:** CreditLens — Executive Risk Report

**Streamlit App:** Open Borrower Risk Assessment

# Case Study Overview

CreditLens examines loan default patterns, borrower affordability and credit-grade risk across 32,581 loan records. It combines PostgreSQL analytics, a Logistic Regression model, Tableau dashboards and a Streamlit borrower-assessment application to translate portfolio findings into practical underwriting recommendations.

# Business Problem

Lenders need to understand which borrower and loan characteristics are associated with higher default rates, where loan exposure is concentrated, and how underwriting reviews can better account for risk. The analysis examines these patterns and evaluates how borrower-level risk scores could support more consistent affordability reviews and exposure management.

# Analysis Scope

Portfolio size, recorded loan amount, defaults and overall Default Rate.

Default patterns across credit grades, income cohorts, loan purpose and home ownership.

Historical-default and delinquency indicators, within the limits of the available data.

Logistic Regression scoring, risk grouping and illustrative Expected Loss estimation.

Executive reporting and interactive borrower-scenario assessment.

# Data Source

**Source: Credit Risk Dataset By Alex Dister, Kaggle**

The dataset used in the analysis contains 32,581 loan-level records and 29 fields covering borrower characteristics, employment, loan attributes, credit history, debt, utilization and delinquency-related indicators. Monetary values are treated as USD in accordance with the supplied data dictionary.

# Analytical Workflow

**Data preparation:** Ingest the source into PostgreSQL, validate record and key integrity, apply documented cleaning rules and create an analytical table.

**SQL analysis:** Build reusable portfolio and risk-segment views using aggregations, conditional logic, CTEs and window functions.

**Risk modelling:** Train a Logistic Regression pipeline with preprocessing and class weighting, evaluate holdout performance and generate model-based default scores.

**Expected Loss:** Combine the model score, recorded loan amount and an assumed 45% loss-given-default (LGD).

**Reporting and application:** Present portfolio findings in Tableau Public and allow users to explore individual borrower scenarios in Streamlit.

# Expected Loss Method

The project estimates Expected Loss using:

Expected Loss = Loan Amount × Model PD × LGD

**Loan Amount:** Recorded loan amount in the dataset.

**Model PD:** Logistic Regression model score for the default outcome.

**LGD:** Assumed loss-given-default of 45%.

The portfolio-level estimate is USD 57.30 million.

# SQL Analysis

**The SQL work covers:**

Portfolio KPIs and default-rate calculations.

Credit-grade, income, home-ownership and loan-intent segmentation.

Interest-rate and credit-grade analysis.

Exposure-weighted risk measures and segment-level Expected Loss proxies.

Historical-default/delinquency proxy analysis.

Reusable analytical views using CTEs, CASE expressions and window functions.

Count-based Default Rate and exposure-weighted default measures are treated as different metrics, rather than being used interchangeably.

# Key Findings

Default risk rises sharply in weaker credit grades. Observed Default Rate increases from **9.96% for Grade A** to **59.05% for Grade D** and **98.44% for Grade G**.

The lowest-income cohort has substantially higher observed risk. Borrowers in the **under-25K income cohort** have a **54.44% Default Rate**, compared with **10.02% for the 200K+ cohort**.

Higher loan burden is associated with higher default rates. The **40%+ loan-burden cohort** has a **38.87% Default Rate**, compared with **11.07% for the under-20% cohort**.

Loan purpose shows meaningful differences. **Debt consolidation** has a **28.59% Default Rate**, followed by **Medical at 26.70%** and **Home Improvement at 26.10%**.

The recorded **Logistic Regression holdout ROC-AUC is 0.8784**. This measures discrimination, not probability calibration or production readiness.

# Recommendations

Strengthen affordability reviews. Route applications with a 40%+ loan-burden measure, particularly when combined with weaker credit grades, for enhanced affordability checks and consider lower initial exposure limits.

Combine risk scores with credit-grade and affordability evidence. Use the model score alongside established underwriting information to identify cases for further review, tighter exposure controls or risk-based pricing assessment.

Introduce clear review tiers for further testing. Evaluate the project's illustrative score bands—below 20%, 20–45% and above 45%—as potential review categories, not automatic approval or rejection rules.

Use income and loan-purpose patterns as review signals. Investigate the circumstances behind higher-risk cohorts without treating income or loan purpose alone as grounds for exclusion.

Monitor outcomes and review the policy over time. Record manual overrides, subsequent loan outcomes and segment-level performance; reassess thresholds and controls as reliable outcome data accumulates.

# Tableau Dashboards

**Executive Risk Overview**

Summarizes portfolio size, total recorded loan amount, Defaults, Portfolio Default Rate, model-based Expected Loss, Default Rate by Grade, exposure by grade and income-cohort risk.

**Underwriting Risk Deep-Dive**

Examines loan-burden patterns, credit-grade interactions, interest-rate/grade combinations, home ownership by risk segment and Default Rate by loan purpose.

# Limitations and Data Quality

Loan-burden interpretation: loan_percent_income is treated as a loan-burden measure. It should not automatically be interpreted as conventional total-debt DTI.

Recorded amount versus disbursal: loan_amnt is the recorded loan amount; verified disbursal is not established by the analysis.

Model calibration and generalization: The holdout ROC-AUC does not establish calibrated probabilities or performance on future applicants.

Expected Loss assumptions: The 45% LGD is an assumption, not a measured recovery outcome. The estimate is not actual loss or proven loss avoidance.

Small cohorts and associations: Grade G contains only 64 loans. Segment rates should be considered alongside cohort size, and observed associations should not be interpreted as causal effects.

# Tools

**Database and SQL:** PostgreSQL, pgAdmin

**Data analysis and modelling:** Python, Pandas, scikit-learn

**Visual analytics:** Tableau Public

**Interactive application:** Streamlit

**Version control and publication:** Git, GitHub, Streamlit Community Cloud

# Repository Structure

```text
creditlens-risk-case-study/
├── data/
│ ├── raw/
│ └── processed/
├── sql/
├── models/
├── app/
├──python/
├── docs/
│ └── Executive_Summary.pdf
├── dashboards/
│ └── screenshots
├── requirements.txt
├── .gitignore
└── README.md
```

# Running the Project

The project can be reproduced locally by preparing the PostgreSQL database, running the SQL analysis and Python modelling workflow, installing the declared dependencies, and launching the Streamlit application.

# Outcome

CreditLens brings together data validation, SQL-based risk analysis, model evaluation and interactive reporting in a single credit-risk workflow. The results identify segments that merit closer underwriting review while documenting the assumptions and validation needed before the analysis could support real lending decisions.
