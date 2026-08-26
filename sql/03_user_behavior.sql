-- =============================================================================
-- 03_USER_BEHAVIOR.SQL
-- Digital Crime Investigation — Transaction Fraud & Anomaly Analytics
-- Phase 3: User Behaviour Profiling & Baseline Establishment
-- =============================================================================

-- ------------------------------------------------------------
-- 3.1  Per-user transaction summary
-- ------------------------------------------------------------
SELECT
    u.user_id,
    u.username,
    u.city          AS registered_city,
    u.account_age_days,
    COUNT(t.transaction_id)                                         AS txn_count,
    ROUND(AVG(t.amount), 0)                                         AS avg_txn_idr,
    ROUND(SUM(t.amount) / 1e6, 2)                                   AS total_spent_million,
    MIN(t.timestamp)                                                 AS first_txn,
    MAX(t.timestamp)                                                 AS last_txn,
    COUNT(DISTINCT t.device_id)                                      AS unique_devices,
    COUNT(DISTINCT t.location_id)                                    AS unique_cities,
    SUM(CASE WHEN t.refund_flag     = 1 THEN 1 ELSE 0 END)          AS refund_count,
    SUM(CASE WHEN t.chargeback_flag = 1 THEN 1 ELSE 0 END)          AS chargeback_count,
    ROUND(100.0 * SUM(CASE WHEN t.refund_flag = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(t.transaction_id), 0), 2)                   AS refund_rate_pct
FROM users u
LEFT JOIN transactions t ON u.user_id = t.user_id
GROUP BY u.user_id, u.username, u.city, u.account_age_days
ORDER BY txn_count DESC;


-- ------------------------------------------------------------
-- 3.2  Device diversity per user (multi-device = risk signal)
-- ------------------------------------------------------------
SELECT
    t.user_id,
    COUNT(DISTINCT t.device_id)  AS device_count,
    STRING_AGG(DISTINCT t.device_id, ', ' ORDER BY t.device_id) AS devices_used
FROM transactions t
GROUP BY t.user_id
HAVING COUNT(DISTINCT t.device_id) > 1
ORDER BY device_count DESC;


-- ------------------------------------------------------------
-- 3.3  Geographic spread per user
--      Users transacting from more cities than their baseline
-- ------------------------------------------------------------
SELECT
    t.user_id,
    u.city                                         AS home_city,
    COUNT(DISTINCT t.location_id)                  AS city_count,
    STRING_AGG(DISTINCT t.location_id, ', '
               ORDER BY t.location_id)             AS cities_visited,
    COUNT(CASE WHEN t.location_id <> u.city
               THEN 1 END)                         AS out_of_home_txn
FROM transactions t
JOIN users u ON t.user_id = u.user_id
GROUP BY t.user_id, u.city
HAVING COUNT(DISTINCT t.location_id) > 1
ORDER BY city_count DESC;


-- ------------------------------------------------------------
-- 3.4  Velocity: transactions per user in rolling 1-hour windows
--      (baseline for burst detection)
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT
        user_id,
        timestamp,
        COUNT(*) OVER (
            PARTITION BY user_id
            ORDER BY timestamp
            RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW
        ) AS txn_in_last_hour
    FROM transactions
)
SELECT
    user_id,
    MAX(txn_in_last_hour)  AS peak_hourly_txn,
    AVG(txn_in_last_hour)  AS avg_hourly_txn
FROM ranked
GROUP BY user_id
ORDER BY peak_hourly_txn DESC
LIMIT 20;


-- ------------------------------------------------------------
-- 3.5  Preferred payment method per user
-- ------------------------------------------------------------
SELECT
    user_id,
    payment_method,
    cnt,
    ROUND(100.0 * cnt / SUM(cnt) OVER (PARTITION BY user_id), 1) AS share_pct
FROM (
    SELECT
        user_id,
        payment_method,
        COUNT(*) AS cnt
    FROM transactions
    GROUP BY user_id, payment_method
) pm
ORDER BY user_id, share_pct DESC;


-- ------------------------------------------------------------
-- 3.6  Cohort: new vs established users — refund rate comparison
--      New account: account_age_days <= 90
-- ------------------------------------------------------------
SELECT
    CASE WHEN u.account_age_days <= 90  THEN 'new_account'
         WHEN u.account_age_days <= 365 THEN 'mid_account'
         ELSE                                'established'
    END                                                        AS cohort,
    COUNT(DISTINCT u.user_id)                                  AS user_count,
    COUNT(t.transaction_id)                                    AS txn_count,
    ROUND(AVG(t.amount), 0)                                    AS avg_txn_idr,
    SUM(CASE WHEN t.refund_flag = 1 THEN 1 ELSE 0 END)        AS refunds,
    ROUND(100.0 * SUM(CASE WHEN t.refund_flag = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(t.transaction_id), 0), 2)             AS refund_rate_pct
FROM users u
LEFT JOIN transactions t ON u.user_id = t.user_id
GROUP BY 1
ORDER BY 1;


-- ------------------------------------------------------------
-- 3.7  Top 20 users by spend, with risk signals
-- ------------------------------------------------------------
SELECT
    t.user_id,
    u.username,
    u.risk_score,
    COUNT(t.transaction_id)                                          AS txn_count,
    ROUND(SUM(t.amount) / 1e6, 2)                                   AS total_million_idr,
    COUNT(DISTINCT t.device_id)                                      AS devices,
    COUNT(DISTINCT t.location_id)                                    AS cities,
    SUM(CASE WHEN t.refund_flag = 1 THEN 1 ELSE 0 END)              AS refunds,
    SUM(CASE WHEN t.chargeback_flag = 1 THEN 1 ELSE 0 END)          AS chargebacks
FROM transactions t
JOIN users u ON t.user_id = u.user_id
GROUP BY t.user_id, u.username, u.risk_score
ORDER BY total_million_idr DESC
LIMIT 20;
