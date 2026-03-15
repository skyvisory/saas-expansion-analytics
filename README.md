# SaaS Expansion Analytics

**Who is ready to buy more?**

A end-to-end expansion revenue intelligence project using machine learning and SHAP explainability to identify and prioritise upsell opportunities across a SaaS customer base.

---

## The Business Problem

Net Revenue Retention (NRR) at 96.7% — below the 100% threshold that signals a self-sustaining growth engine. Contraction MRR of $459K from downgrades is offsetting $1.26M in expansion gains. This project answers three questions:

1. **How much expansion revenue is available?** ($8.6M ARR addressable)
2. **Which accounts are most likely to upgrade?** (ML model + readiness score)
3. **Why is each account ready?** (SHAP explainability → CSM talking points)

---

## Portfolio Context

| Project | Question | Tools |
|---|---|---|
| Project 1: Customer Churn | Who will leave? | PostgreSQL, ML, XGBoost |
| Project 2: Sales Pipeline | What will close? | DuckDB, SQL, Streamlit |
| **Project 3: SaaS Expansion** | **Who will buy more?** | **PostgreSQL, ML, SHAP** |

**Retain → Close → Expand** — three complementary revenue analytics projects.

---

## Dataset

**RavenStack** by Rivalytics — synthetic SaaS subscription dataset.  
Source: [Kaggle](https://www.kaggle.com/datasets/rivalytics/saas-subscription-and-churn-analytics-dataset)  
Credit: Dataset by River @ Rivalytics, used under MIT-style license.

| Table | Rows | Description |
|---|---|---|
| accounts | 500 | Company profiles, industry, plan tier |
| subscriptions | 5,000 | MRR, seats, upgrade/downgrade flags |
| feature_usage | 25,000 | Feature-level usage events per subscription |
| support_tickets | 2,000 | Ticket volume, satisfaction, escalations |
| churn_events | 600 | Churn and reactivation history |

---

## Key Results

### NRR Analysis
| Component | MRR |
|---|---|
| Starting MRR | $11,338,747 |
| + Expansion (upgrades) | $1,262,997 |
| - Churned MRR | $1,179,139 |
| - Contraction (downgrades) | $459,366 |
| **Ending MRR** | **$10,963,239** |
| **NRR** | **96.7%** |

### Expansion Opportunity
| Motion | Accounts | Avg Uplift | Total ARR |
|---|---|---|---|
| Basic → Pro | 131 | $941/mo | $1,479,252 |
| Pro → Enterprise | 139 | $4,286/mo | $7,149,048 |
| **Total** | **270** | | **$8,628,300** |

Realistic 15% quarterly conversion: **$107,854/mo incremental MRR**

### Model Performance
| Metric | Value |
|---|---|
| Model | Logistic Regression |
| AUC-ROC | 0.618 |
| Target variable | upgrade_flag |
| Features | 25 (usage, subscription, support, profile) |

AUC of 0.618 reflects the synthetic nature of the dataset. On real CRM data with genuine behavioural signals, performance would improve. The SHAP explanations remain actionable regardless of score.

### Top Expansion Signals
| Feature | SHAP Impact | Direction |
|---|---|---|
| total_usage_duration | 0.570 | ↑ More time in product → more likely to upgrade |
| n_subscriptions | 0.417 | ↑ Longer customer history → more likely to upgrade |
| n_escalations | 0.220 | ↑ Engaged accounts escalate — proxy for power users |
| total_mrr | 0.194 | ↑ Higher spend → more invested in platform |
| n_tickets | -0.213 | ↓ High ticket volume signals friction not expansion |

### Top 5 Expansion Targets (ML Model)
| Account | Industry | Plan | MRR | Score | Top Signal |
|---|---|---|---|---|---|
| Company_82 | DevTools | Pro | $34,243 | 87.0 | usage_duration, n_subscriptions |
| Company_364 | DevTools | Basic | $27,215 | 85.1 | usage_duration, n_subscriptions |
| Company_287 | DevTools | Basic | $32,385 | 84.9 | usage_duration, n_subscriptions |
| Company_40 | FinTech | Basic | $51,109 | 84.6 | usage_duration, n_subscriptions |
| Company_258 | HealthTech | Basic | $40,098 | 83.9 | usage_duration, n_subscriptions |

---

## Project Structure
```
saas-expansion-analytics/
├── notebooks/
│   ├── 01_data_profiling.ipynb       # Data quality, schema validation
│   ├── 02_expansion_metrics.ipynb    # MRR, NRR, upgrade rates
│   ├── 03_expansion_signals.ipynb    # Feature engineering, signal analysis
│   ├── 04_expansion_model.ipynb      # Logistic regression, SHAP values
│   ├── 05_target_list.ipynb          # Prioritised target list, board memo
│   └── 06_sql_analysis.ipynb         # SQL replication across all 5 tables
├── sql/
│   └── 01_expansion_analysis.sql     # 5 queries — MRR, NRR, targets
├── data/
│   ├── raw/                          # Source CSVs (gitignored)
│   └── processed/                    # Feature tables, scored accounts
├── outputs/
│   └── shap_summary.png              # SHAP feature importance plot
└── requirements.txt
```

---

## Methodology

### Expansion Readiness Score

A 0-100 score per account derived from logistic regression probability:
```
Raw features (5 tables)
    ↓ aggregate per account (Notebook 03)
Feature table — 25 signals per account
    ↓ logistic regression trained on upgrade_flag
Upgrade probability (0-1)
    ↓ × 100
Expansion readiness score (0-100)
    ↓ pd.cut()
Priority tier (Tier 1 → Tier 4)
```

### SHAP Explainability

Each account's score includes a top 3 SHAP explanation — the specific features that drove their score up or down:
```
Company_82 (score 87.0):
n_subscriptions (+1.20) | total_usage_duration (+1.02) | total_usage_count (-1.02)

CSM talking point:
"Your team has been with us through multiple renewal cycles
 and consistently ranks in the top 10% of product usage —
 let's talk about what Enterprise unlocks for you."
```

SHAP reasons are saved in `data/processed/scored_accounts.csv` and can be passed directly to an LLM to generate personalised CSM outreach at scale.

### SQL vs ML Scoring

Two independent scoring approaches validate each other:

| Approach | Method | Top signal |
|---|---|---|
| ML model | Logistic regression on 25 features | Behavioural patterns |
| SQL score | Weighted composite (usage 40%, seats 30%, MRR 20%, history 10%) | Raw size signals |

Five accounts appear in both top 20 lists — these are the highest confidence expansion targets validated by two independent methodologies.

---

## Key Findings

**1. NRR below 100% — contraction is the problem:**
Expansion MRR ($1.26M) nearly matches churned MRR ($1.18M) — the real drag is $459K in contraction from downgrades. Reducing downgrades delivers faster NRR improvement than driving new upsells.

**2. Two expansion motions with different economics:**
Basic → Pro: 131 accounts, $941/mo uplift, higher readiness scores (avg 56.9)
Pro → Enterprise: 139 accounts, $4,286/mo uplift, lower readiness scores (avg 43.1)
Volume vs value — both motions need separate CSM playbooks.

**3. Usage duration dominates all other signals:**
Time spent in the product (total_usage_duration) has the strongest positive coefficient (0.570) — depth of engagement matters more than frequency, breadth, or account size.

**4. HealthTech and DevTools are the highest-yield segments:**
HealthTech upgrades at up to 15.9% (event channel), DevTools at 13.8% (ads channel). EdTech consistently underperforms at 5.6-7.9% regardless of acquisition channel.

**5. Partner channel produces the highest-quality expansion leads:**
Partner-acquired accounts upgrade at 12% vs 9.7% for unattributed. Combined with FinTech industry: 14% upgrade rate — the highest-value acquisition segment.

---

## Limitations

- **Synthetic dataset:** upgrade_flag generation logic may not reflect real behavioural patterns — AUC of 0.618 reflects this. Real CRM data would produce stronger signal.
- **Small sample:** 500 accounts limits model complexity. Logistic regression chosen deliberately for interpretability over raw accuracy.
- **Multicollinearity:** total_usage_duration and total_usage_count are correlated, producing opposite SHAP signs. In production these would be combined into a single engagement score.
- **Static snapshot:** no time-series dimension — a production model would score accounts weekly and track score velocity (accounts trending up are higher priority than static high scorers).

---

## KPIs to Track in Production

| Cadence | Metric | Target |
|---|---|---|
| Weekly | Tier 1 outreach completion | 100% of 26 accounts contacted |
| Weekly | Accounts moving into Tier 1 | Flag any new entries |
| Monthly | Expansion MRR converted | $107,854/mo (15% conversion) |
| Monthly | NRR by segment | Improve from 96.7% baseline |
| Monthly | Contraction MRR | Reduce from $459K baseline |
| Quarterly | Tier 1 conversion rate | 2-3x higher than Tier 3 |
| Quarterly | Model AUC on new data | Retrain if below 0.60 |
| Quarterly | Pro → Enterprise conversion | 15% of 139 Pro accounts |

---

## Tech Stack

| Tool | Purpose |
|---|---|
| Python 3.11 | Core language |
| pandas | Data manipulation |
| DuckDB | In-memory SQL engine |
| scikit-learn | Logistic regression, Pipeline |
| SHAP 0.51.0 | Model explainability |
| Plotly | Interactive visualisations |
| Jupyter | Analysis notebooks |

---

## Setup
```bash
git clone https://github.com/YOUR_USERNAME/saas-expansion-analytics
cd saas-expansion-analytics
pip install -r requirements.txt
```

Download the RavenStack dataset from [Kaggle](https://www.kaggle.com/datasets/rivalytics/saas-expansion-analytics-dataset) and place CSVs in `data/raw/`.

Run notebooks in order: 01 → 06.

---

*Dataset: RavenStack by River @ Rivalytics*