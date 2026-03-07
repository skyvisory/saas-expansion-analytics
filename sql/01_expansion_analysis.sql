-- ============================================================
-- SaaS Expansion Analytics — SQL Analysis
-- Dataset: RavenStack by Rivalytics
-- ============================================================


-- ── Query 1: MRR by Plan Tier and Month ─────────────────────
-- Monthly MRR breakdown by plan — tracks revenue mix over time

SELECT
    STRFTIME(start_date::DATE, '%Y-%m')         AS month,
    plan_tier,
    COUNT(*)                                     AS subscriptions,
    SUM(mrr_amount)                              AS total_mrr,
    ROUND(AVG(mrr_amount), 0)                    AS avg_mrr,
    ROUND(SUM(mrr_amount) * 100.0
        / SUM(SUM(mrr_amount)) OVER
        (PARTITION BY STRFTIME(start_date::DATE,
        '%Y-%m')), 1)                            AS pct_of_month_mrr
FROM subscriptions
WHERE mrr_amount > 0
  AND end_date IS NULL
GROUP BY month, plan_tier
ORDER BY month, plan_tier;


-- ── Query 2: Upgrade Rates by Industry and Referral ─────────
-- Which segments produce the most expansion?

SELECT
    a.industry,
    a.referral_source,
    COUNT(DISTINCT a.account_id)                AS total_accounts,
    COUNT(s.subscription_id)                     AS total_subscriptions,
    SUM(CASE WHEN s.upgrade_flag = TRUE
        THEN 1 ELSE 0 END)                       AS upgrades,
    ROUND(SUM(CASE WHEN s.upgrade_flag = TRUE
        THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(s.subscription_id),
        0) * 100, 1)                             AS upgrade_rate_pct,
    ROUND(AVG(s.mrr_amount), 0)                  AS avg_mrr
FROM accounts a
JOIN subscriptions s
    ON a.account_id = s.account_id
WHERE s.mrr_amount > 0
GROUP BY a.industry, a.referral_source
ORDER BY upgrade_rate_pct DESC;


-- ── Query 3: Account-Level Feature Summary ───────────────────
-- Joins all 5 tables — full account intelligence view

WITH sub_summary AS (
    SELECT
        account_id,
        COUNT(subscription_id)              AS n_subscriptions,
        SUM(mrr_amount)                     AS total_mrr,
        SUM(seats)                          AS total_seats,
        MAX(CASE WHEN upgrade_flag = TRUE
            THEN 1 ELSE 0 END)              AS has_upgraded,
        MAX(CASE WHEN downgrade_flag = TRUE
            THEN 1 ELSE 0 END)              AS has_downgraded
    FROM subscriptions
    WHERE mrr_amount > 0
      AND end_date IS NULL
    GROUP BY account_id
),
usage_summary AS (
    SELECT
        a.account_id,
        COUNT(fu.usage_id)                  AS total_usage_events,
        SUM(fu.usage_count)                 AS total_usage_count,
        SUM(fu.usage_duration_secs)         AS total_usage_duration,
        COUNT(DISTINCT fu.feature_name)     AS unique_features_used,
        SUM(fu.error_count)                 AS total_errors
    FROM subscriptions s
    JOIN feature_usage fu
        ON s.subscription_id = fu.subscription_id
    JOIN accounts a
        ON s.account_id = a.account_id
    WHERE s.end_date IS NULL
    GROUP BY a.account_id
),
support_summary AS (
    SELECT
        account_id,
        COUNT(ticket_id)                    AS n_tickets,
        ROUND(AVG(satisfaction_score), 2)   AS avg_satisfaction,
        SUM(CASE WHEN escalation_flag = TRUE
            THEN 1 ELSE 0 END)              AS n_escalations,
        ROUND(AVG(resolution_time_hours),
            2)                              AS avg_resolution_hours
    FROM support
    GROUP BY account_id
)
SELECT
    a.account_id,
    a.account_name,
    a.industry,
    a.plan_tier,
    a.referral_source,
    a.churn_flag,
    ss.n_subscriptions,
    ss.total_mrr,
    ss.total_seats,
    ss.has_upgraded,
    ss.has_downgraded,
    COALESCE(us.total_usage_count, 0)       AS total_usage_count,
    COALESCE(us.total_usage_duration, 0)    AS total_usage_duration,
    COALESCE(us.unique_features_used, 0)    AS unique_features_used,
    COALESCE(us.total_errors, 0)            AS total_errors,
    COALESCE(sp.n_tickets, 0)               AS n_tickets,
    COALESCE(sp.avg_satisfaction, 0)        AS avg_satisfaction,
    COALESCE(sp.n_escalations, 0)           AS n_escalations
FROM accounts a
LEFT JOIN sub_summary ss
    ON a.account_id = ss.account_id
LEFT JOIN usage_summary us
    ON a.account_id = us.account_id
LEFT JOIN support_summary sp
    ON a.account_id = sp.account_id
WHERE a.churn_flag = FALSE
ORDER BY ss.total_mrr DESC NULLS LAST;


-- ── Query 4: NRR Calculation ─────────────────────────────────
-- Net Revenue Retention — key SaaS health metric

WITH mrr_components AS (
    SELECT
        SUM(mrr_amount)                         AS total_mrr,
        SUM(CASE WHEN upgrade_flag = TRUE
            THEN mrr_amount ELSE 0 END)         AS expansion_mrr,
        SUM(CASE WHEN churn_flag = TRUE
            THEN mrr_amount ELSE 0 END)         AS churned_mrr,
        SUM(CASE WHEN downgrade_flag = TRUE
            THEN mrr_amount ELSE 0 END)         AS contraction_mrr
    FROM subscriptions
    WHERE mrr_amount > 0
)
SELECT
    total_mrr                                   AS starting_mrr,
    expansion_mrr,
    churned_mrr,
    contraction_mrr,
    total_mrr
        + expansion_mrr
        - churned_mrr
        - contraction_mrr                       AS ending_mrr,
    ROUND((total_mrr
        + expansion_mrr
        - churned_mrr
        - contraction_mrr)
        * 100.0 / total_mrr, 1)                 AS nrr_pct
FROM mrr_components;


-- ── Query 5: Top Expansion Targets ───────────────────────────
-- Ranks active Basic and Pro accounts by composite expansion signal

WITH sub_signals AS (
    SELECT
        account_id,
        SUM(mrr_amount)                         AS total_mrr,
        SUM(seats)                              AS total_seats,
        COUNT(subscription_id)                  AS n_subscriptions
    FROM subscriptions
    WHERE mrr_amount > 0
      AND end_date IS NULL
    GROUP BY account_id
),
usage_signals AS (
    SELECT
        a.account_id,
        SUM(fu.usage_duration_secs)             AS total_usage_duration,
        COUNT(DISTINCT fu.feature_name)         AS unique_features_used
    FROM subscriptions s
    JOIN feature_usage fu
        ON s.subscription_id = fu.subscription_id
    JOIN accounts a
        ON s.account_id = a.account_id
    WHERE s.end_date IS NULL
    GROUP BY a.account_id
),
support_signals AS (
    SELECT
        account_id,
        ROUND(AVG(satisfaction_score), 2)       AS avg_satisfaction,
        SUM(CASE WHEN escalation_flag = TRUE
            THEN 1 ELSE 0 END)                  AS n_escalations
    FROM support
    GROUP BY account_id
)
SELECT
    a.account_id,
    a.account_name,
    a.industry,
    a.plan_tier,
    a.referral_source,
    ss.total_mrr,
    ss.total_seats,
    ss.n_subscriptions,
    COALESCE(us.total_usage_duration, 0)        AS total_usage_duration,
    COALESCE(us.unique_features_used, 0)        AS unique_features_used,
    COALESCE(sp.avg_satisfaction, 0)            AS avg_satisfaction,
    COALESCE(sp.n_escalations, 0)               AS n_escalations,
    ROUND(
        (COALESCE(us.total_usage_duration, 0)
            / 100000.0 * 40)
        + (ss.total_seats / 500.0 * 30)
        + (ss.total_mrr / 50000.0 * 20)
        + (ss.n_subscriptions / 20.0 * 10)
    , 1)                                        AS sql_expansion_score
FROM accounts a
JOIN sub_signals ss
    ON a.account_id = ss.account_id
LEFT JOIN usage_signals us
    ON a.account_id = us.account_id
LEFT JOIN support_signals sp
    ON a.account_id = sp.account_id
WHERE a.churn_flag = FALSE
  AND a.plan_tier IN ('Basic', 'Pro')
ORDER BY sql_expansion_score DESC
LIMIT 20;