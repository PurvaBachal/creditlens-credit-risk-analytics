from __future__ import annotations

from pathlib import Path
from typing import Any

import joblib
import pandas as pd
import streamlit as st

APP_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = APP_DIR.parent if APP_DIR.name.lower() == "app" else APP_DIR
MODEL_PATH = PROJECT_ROOT / "models" / "logistic_model.pkl"
TRAINING_DATA_PATH = PROJECT_ROOT / "data" / "credit_risk_ml.csv"
LOSS_GIVEN_DEFAULT = 0.45

NUMERIC_FEATURES = [
    "person_age",
    "person_income",
    "person_emp_length",
    "loan_amnt",
    "loan_int_rate",
    "loan_percent_income",
    "cb_person_cred_hist_length",
    "loan_term_months",
    "loan_to_income_ratio",
    "other_debt",
    "debt_to_income_ratio",
    "open_accounts",
    "credit_utilization_ratio",
    "past_delinquencies",
    ]
CATEGORICAL_FEATURES = [
    "loan_grade",
    "person_home_ownership",
    "loan_intent",
    "cb_person_default_on_file",]

FEATURE_COLUMNS = NUMERIC_FEATURES + CATEGORICAL_FEATURES

FALLBACK_CATEGORIES = {
    "loan_grade": ["A", "B", "C", "D", "E", "F", "G"],
    "person_home_ownership": ["RENT", "MORTGAGE", "OWN", "OTHER"],
    "loan_intent": [
        "PERSONAL",
        "EDUCATION",
        "MEDICAL",
        "VENTURE",
        "HOMEIMPROVEMENT",
        "DEBTCONSOLIDATION",
    ],
    "cb_person_default_on_file": ["N", "Y"],
}

st.set_page_config(
    page_title="CreditLens | Borrower Risk Assessment",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="collapsed",
)

st.markdown(
    """
    <style>
    :root {--navy:#173F67;--ink:#263648;--muted:#66768A;--line:#DCE4EC;}
    html,body,[class*="css"]{font-family:Arial,Helvetica,sans-serif;}
    [data-testid="stAppViewContainer"]{background:#F5F7FA;color:var(--ink);}
    [data-testid="stHeader"]{background:transparent;}
    .block-container{max-width:1380px;padding-top:1.4rem;padding-bottom:2rem;}
    [data-testid="stMetric"]{min-height:112px;background:white;border:1px solid var(--line);border-radius:10px;padding:1rem 1.1rem;}
    [data-testid="stMetricLabel"] p{color:var(--muted);font-size:.84rem;}
    [data-testid="stMetricValue"]{color:var(--navy);font-size:1.45rem;font-weight:700;white-space:normal;overflow-wrap:anywhere;}
    [data-testid="stForm"]{background:white;border:1px solid var(--line);border-radius:12px;padding:1rem 1.1rem;}
    [data-testid="stWidgetLabel"] p{font-size:.86rem;font-weight:600;}
    .field-label{color:var(--ink);font-size:.86rem;font-weight:600;line-height:1.3;}
    div[data-testid="stFormSubmitButton"]>button{background:var(--navy);color:white;border:1px solid var(--navy);font-weight:700;}
    .muted-note{color:var(--muted);font-size:.8rem;line-height:1.5;}
    </style> """,
    unsafe_allow_html=True,
)


def render_field_label(label: str) -> None:
    st.markdown(f'<div class="field-label">{label}</div>', unsafe_allow_html=True)


@st.cache_resource(show_spinner="Loading the CreditLens model…")
def load_model(path: str) -> Any:
    model_file = Path(path)
    if not model_file.is_file():
        raise FileNotFoundError

    model = joblib.load(model_file)
    if not hasattr(model, "predict_proba"):
        raise TypeError("The saved model does not support probability scoring.")
    return model


@st.cache_data(show_spinner=False)
def load_training_ranges(
    path: str, modified_time: float
) -> dict[str, tuple[float, float]]:
    """For optional input warnings, load numeric training ranges."""
    try:
        frame = pd.read_csv(path, usecols=NUMERIC_FEATURES)
        ranges = {}
        for column in NUMERIC_FEATURES:
            values = pd.to_numeric(frame[column], errors="coerce").dropna()
            if not values.empty:
                ranges[column] = (float(values.min()), float(values.max()))
        return ranges
    except (OSError, ValueError, KeyError, pd.errors.ParserError):
        return {}


def model_categories(model: Any, feature: str) -> list[str]:
    try:
        encoder = (
            model.named_steps["preprocessor"]
            .named_transformers_["categorical"]
            .named_steps["encoder"]
        )
        index = CATEGORICAL_FEATURES.index(feature)
        values = [str(value) for value in encoder.categories_[index]]
        values = [value for value in values if value and value.lower() != "nan"]
        if values:
            return values
    except (AttributeError, KeyError, IndexError, TypeError, ValueError):
        pass
    return FALLBACK_CATEGORIES[feature]


def preferred_index(options: list[str], preferred: str) -> int:
    return next(
        (index for index, value in enumerate(options)
         if value.casefold() == preferred.casefold()),
        0,
    )


def display_category(value: str) -> str:
    """Made encoded source categories easier to read in the form."""
    labels = {
        "Y": "Yes",
        "N": "No",
        "HOMEIMPROVEMENT": "Home improvement",
        "DEBTCONSOLIDATION": "Debt consolidation",
    }
    return labels.get(value.upper(), value.replace("_", " ").title())


def score_band(score: float) -> str:
    """Returns the fixed score grouping that is used for this case study only."""
    if score < 0.20:
        return "Lower (<20%)"
    if score <= 0.45:
        return "Middle (20–45%)"
    return "Higher (>45%)"


def build_feature_row(values: dict[str, Any]) -> pd.DataFrame:
    return pd.DataFrame(
        [{column: values[column] for column in FEATURE_COLUMNS}],
        columns=FEATURE_COLUMNS,
    )


def range_warnings(
    values: dict[str, Any], ranges: dict[str, tuple[float, float]]
) -> list[str]:
    warnings = []
    percent_features = {
        "loan_percent_income",
        "debt_to_income_ratio",
        "credit_utilization_ratio",
    }
    display_names = {
        "loan_percent_income": "Loan amount as % of annual income",
        "loan_to_income_ratio": "Loan-to-income ratio (source field)",
        "debt_to_income_ratio": "Debt-to-income ratio",
        "credit_utilization_ratio": "Credit utilization",
        "person_emp_length": "Employment length (years)",
        "cb_person_cred_hist_length": "Credit history length (years)",
        "past_delinquencies": "Past delinquencies",
        "open_accounts": "Open credit accounts",
        "loan_int_rate": "Interest rate (%)",
        "loan_amnt": "Requested loan amount (USD)",
        "person_income": "Annual income (USD)",
        "person_age": "Age (years)",
        "other_debt": "Other existing debt (USD)",
        "loan_term_months": "Loan term (months)",
    }

    for feature, (minimum, maximum) in ranges.items():
        value = float(values[feature])
        if value < minimum or value > maximum:
            label = display_names.get(feature, feature.replace("_", " ").title())
            if feature in percent_features:
                low_text, high_text = f"{minimum:.1%}", f"{maximum:.1%}"
            else:
                low_text, high_text = f"{minimum:,.3g}", f"{maximum:,.3g}"
            warnings.append(
                f"{label}: outside the observed training range ({low_text} to {high_text})."
            )
    return warnings


try:
    model = load_model(str(MODEL_PATH))
    default_class_index = list(model.classes_).index(1)
except FileNotFoundError:
    st.error("CreditLens could not find `models/logistic_model.pkl` in the project.")
    st.stop()
except (AttributeError, ValueError):
    st.error("The saved model does not expose the expected default class (`loan_status = 1`).")
    st.stop()
except Exception as error:
    st.error("CreditLens could not load the model. Check the model file and package versions.")
    st.caption(f"Loading detail: {type(error).__name__}")
    st.stop()

training_ranges: dict[str, tuple[float, float]] = {}
if TRAINING_DATA_PATH.is_file():
    training_ranges = load_training_ranges(
        str(TRAINING_DATA_PATH), TRAINING_DATA_PATH.stat().st_mtime
    )


# Portfolio snapshot is from the completed case-study analysis.
st.markdown("## CreditLens")
st.markdown("### Borrower Risk Assessment")
st.caption(
    "Enter a borrower and loan profile to see the saved model's score for that scenario. "
    "All amounts are shown in USD.")

kpis = st.columns(4, gap="medium")
kpis[0].metric("Total loans", "32,581")
kpis[1].metric("Total loan amount", "$312.43M")
kpis[2].metric("Defaults", "7,108")
kpis[3].metric("Portfolio default rate", "21.82%")
st.caption(
    "This credit decision system is a portfolio case-study tool, not a real-world credit decision system.")
st.divider()

st.markdown("### Borrower scenario")

with st.form("creditlens_assessment_form", clear_on_submit=False):
    borrower_col, loan_col, credit_col = st.columns([1, 1.08, 1], gap="large")

    with borrower_col:
        st.markdown("**01 · Borrower & employment**")
        render_field_label("Borrower Age (years)")
        person_age = st.number_input(
            "Borrower Age (years)", min_value=18, max_value=100, value=32, step=1,
            label_visibility="collapsed",)
        render_field_label("Annual Income (USD)")
        person_income = st.number_input(
            "Annual Income (USD)",
            min_value=1.0,
            value=60_000.0,
            step=1_000.0,
            format="%.0f",
            help="Enter annual income, not monthly income.",
            label_visibility="collapsed",
        )
        render_field_label("Employment Length (years)")
        person_emp_length = st.number_input(
            "Employment Length (years)",
            min_value=0.0,
            value=5.0,
            step=0.5,
            format="%.1f",
            label_visibility="collapsed",
        )
        render_field_label("Home Ownership")
        home_options = model_categories(model, "person_home_ownership")
        person_home_ownership = st.selectbox(
            "Home Ownership",
            home_options,
            index=preferred_index(home_options, "RENT"),
            format_func=display_category,
            label_visibility="collapsed",
        )
        render_field_label("Credit History Length (years)")
        cb_person_cred_hist_length = st.number_input(
            "Credit History Length (years)",
            min_value=0.0,
            value=6.0,
            step=0.5,
            format="%.1f",
            label_visibility="collapsed",
        )
        render_field_label("Previous Default on File")
        history_options = model_categories(model, "cb_person_default_on_file")
        cb_person_default_on_file = st.selectbox(
            "Previous Default on File",
            history_options,
            index=preferred_index(history_options, "N"),
            format_func=display_category,
            label_visibility="collapsed",
        )

    with loan_col:
        st.markdown("**02 · Loan request**")
        render_field_label("Requested Loan Amount (USD)")
        loan_amnt = st.number_input(
            "Requested Loan Amount (USD)",
            min_value=1.0,
            value=10_000.0,
            step=500.0,
            format="%.0f",
            help="This is the requested/recorded loan amount, not confirmed disbursed capital.",
            label_visibility="collapsed",
        )
        render_field_label("Interest Rate (%)")
        loan_int_rate = st.number_input(
            "Interest Rate (%)",
            min_value=0.0,
            max_value=100.0,
            value=12.5,
            step=0.25,
            format="%.2f",
            label_visibility="collapsed",
        )
        render_field_label("Loan Grade")
        grade_options = model_categories(model, "loan_grade")
        loan_grade = st.selectbox(
            "Loan Grade",
            grade_options,
            index=preferred_index(grade_options, "C"),
            label_visibility="collapsed",
        )
        render_field_label("Loan Term (months)")
        loan_term_months = st.number_input(
            "Loan Term (months)", min_value=1, value=36, step=1,
            label_visibility="collapsed",
        )
        render_field_label("Loan Purpose")
        intent_options = model_categories(model, "loan_intent")
        loan_intent = st.selectbox(
            "Loan Purpose",
            intent_options,
            index=preferred_index(intent_options, "PERSONAL"),
            format_func=display_category,
            label_visibility="collapsed",
        )
        render_field_label("Loan Amount as % of Annual Income")
        loan_percent_income_pct = st.number_input(
            "Loan Amount as % of Annual Income",
            min_value=0.0,
            max_value=100.0,
            value=16.7,
            step=0.5,
            format="%.1f",
            help="Enter a percentage (for example, 16.7 for 16.7%). The app converts it to a decimal for the model.",
            label_visibility="collapsed",
        )
        render_field_label("Loan-to-Income Ratio (source field)")
        loan_to_income_ratio = st.number_input(
            "Loan-to-Income Ratio (source field)",
            min_value=0.0,
            value=0.167,
            step=0.01,
            format="%.3f",
            help="Enter the separate source value as a decimal; for example, 0.167 represents 16.7%.",
            label_visibility="collapsed",
        )

    with credit_col:
        st.markdown("**03 · Credit history & existing debt**")
        render_field_label("Other Existing Debt (USD)")
        other_debt = st.number_input(
            "Other Existing Debt (USD)",
            min_value=0.0,
            value=1_500.0,
            step=250.0,
            format="%.0f",
            label_visibility="collapsed",
        )
        render_field_label("Debt-to-Income Ratio (%)")
        debt_to_income_ratio_pct = st.number_input(
            "Debt-to-Income Ratio (%)",
            min_value=0.0,
            value=22.0,
            step=1.0,
            format="%.1f",
            help="Enter a percentage (for example, 22 for 22%). The app converts it to a decimal for the model.",
            label_visibility="collapsed",
        )
        render_field_label("Open Credit Accounts")
        open_accounts = st.number_input(
            "Open Credit Accounts", min_value=0, value=6, step=1,
            label_visibility="collapsed",
        )
        render_field_label("Credit Utilization (%)")
        credit_utilization_pct = st.number_input(
            "Credit Utilization (%)",
            min_value=0.0,
            max_value=100.0,
            value=35.0,
            step=1.0,
            format="%.1f",
            help="Enter a percentage. The app converts it to a decimal for the model.",
            label_visibility="collapsed",
        )
        render_field_label("Past Delinquencies (count)")
        past_delinquencies = st.number_input(
            "Past Delinquencies (count)", min_value=0, value=0, step=1,
            label_visibility="collapsed",
        )

    submitted = st.form_submit_button("Run risk assessment", use_container_width=True)


if submitted:
    errors = []
    if person_emp_length > max(0, person_age - 14):
        errors.append("Employment length looks too high for the entered age.")
    if cb_person_cred_hist_length > max(0, person_age - 14):
        errors.append("Credit history length looks too high for the entered age.")

    if errors:
        st.session_state.pop("creditlens_assessment", None)
        for message in errors:
            st.error(message)
    else:
        values: dict[str, Any] = {
            "person_age": int(person_age),
            "person_income": float(person_income),
            "person_emp_length": float(person_emp_length),
            "loan_amnt": float(loan_amnt),
            "loan_int_rate": float(loan_int_rate),
            "loan_percent_income": float(loan_percent_income_pct) / 100.0,
            "cb_person_cred_hist_length": float(cb_person_cred_hist_length),
            "loan_term_months": int(loan_term_months),
            "loan_to_income_ratio": float(loan_to_income_ratio),
            "other_debt": float(other_debt),
            "debt_to_income_ratio": float(debt_to_income_ratio_pct) / 100.0,
            "open_accounts": int(open_accounts),
            "credit_utilization_ratio": float(credit_utilization_pct) / 100.0,
            "past_delinquencies": int(past_delinquencies),
            "loan_grade": str(loan_grade),
            "person_home_ownership": str(person_home_ownership),
            "loan_intent": str(loan_intent),
            "cb_person_default_on_file": str(cb_person_default_on_file),
        }

        try:
            score = float(
                model.predict_proba(build_feature_row(values))[0][default_class_index]
            )
            score = min(max(score, 0.0), 1.0)
            st.session_state["creditlens_assessment"] = {
                "score": score,
                "score_band": score_band(score),
                "loan_amount": float(loan_amnt),
                "expected_loss": float(loan_amnt) * score * LOSS_GIVEN_DEFAULT,
                "range_warnings": range_warnings(values, training_ranges),
                "range_check_available": bool(training_ranges),
            }
        except Exception as error:
            st.session_state.pop("creditlens_assessment", None)
            st.error(
                "CreditLens could not score these inputs. Check that the saved model "
                "matches the feature schema."
            )
            st.caption(f"Scoring detail: {type(error).__name__}")


# Submitted results kept visible when streamlit reruns after interaction .
assessment = st.session_state.get("creditlens_assessment")
if assessment:
    st.divider()
    st.markdown("### Assessment result")
    st.caption("These results describe the entered scenario, not a lending decision.")

    results = st.columns([1, 1, 1.15], gap="medium")
    results[0].metric("Model-estimated default score", f"{assessment['score']:.2%}")
    results[1].metric("Case-study score band", assessment["score_band"])
    results[2].metric(
        "Illustrative expected-loss estimate",
        f"${assessment['expected_loss']:,.0f}",)

    st.markdown(
        "**Expected-loss estimate = Requested loan amount × model score × assumed LGD (45%).**")
    st.caption(
        f"For this scenario, the requested loan amount is ${assessment['loan_amount']:,.0f}. "
        "The model score is used as a proxy in the formula.")
    st.info(
        "The score has not been calibrated for real-world lending. Treat the score band "
        "and expected-loss estimate as case-study outputs, not as a confirmed default "
        "probability, actual loss, or approval recommendation.")

    if assessment["range_warnings"]:
        st.warning(
            "Some inputs are outside the ranges seen in the local modelling data. "
            "The score may be less reliable for this scenario.")
        with st.expander("View inputs outside the training range"):
            for warning in assessment["range_warnings"]:
                st.write(f"- {warning}")
    elif not assessment["range_check_available"]:
        st.caption(
            "Input-range checks are unavailable because `data/processed/credit_risk_ml.csv` "
            "was not found at the expected path.")

    with st.expander("How to read these results"):
        st.markdown(
            "- **Model-estimated default score:** the saved Logistic Regression model's "
            "score for the entered profile where `loan_status = 1` represents default. "
            "It has not been shown to be a calibrated real-world probability.\n"
            "- **Case-study score band:** lower is below 20%, middle is 20%–45%, and "
            "higher is above 45%. These cutoffs were set for this project; they are not "
            "approval or rejection rules.\n"
            "- **Illustrative expected-loss estimate:** requested loan amount × model score × "
            "assumed 45% loss given default (LGD). This is not actual or booked loss.\n"
            "- **Model limitation:** the model was trained with class weighting. It would "
            "need further validation and probability calibration before any real lending use."
        )

st.markdown(
    '<p class="muted-note">CreditLens · FinTech credit-risk case study · '
    'Amounts in USD · '
    'Scenario scoring is illustrative and is not for real credit decisions.</p>',
    unsafe_allow_html=True,
)
