-- =============================================================================
-- 04_ANOMALY_ANALYSIS.SQL
-- Digital Crime Investigation — Transaction Fraud & Anomaly Analytics
-- Phase 4: Anomaly Detection Queries (Indicators A–G)
-- =============================================================================


-- ============================================================
-- INDICATOR A — IMPOSSIBLE TRAVEL
-- Two consecutive transactions by the same user from locations
-- that are geographically incompatible with the elapsed time.
-- Threshold: > 1 hour travel time assumed between cities
-- ============================================================
WITH consecutive AS (
    SELECT
        user_id,
        transaction_id,
        timestamp,
        location_id,
        amount,
        device_id,
        LAG(timestamp,    1) OVER (PARTITION BY user_id ORDER BY timestamp) AS prev_timestamp,
        LAG(location_id,  1) OVER (PARTITION BY user_id ORDER BY timestamp) AS prev_location,
        LAG(transaction_id,1) OVER (PARTITION BY user_id ORDER BY timestamp) AS prev_txn_id
    FROM transactions
)
SELECT
    user_id,
    prev_txn_id           AS from_txn,
    transaction_id        AS to_txn,
    prev_location         AS from_city,
    location_id           AS to_city,
    prev_timestamp        AS from_time,
    timestamp             AS to_time,
    ROUND(EXTRACT(EPOCH FROM (timestamp - prev_timestamp)) / 60, 1) AS gap_minutes,
    amount,
    device_id             AS device_at_destination
FROM consecutive
WHERE prev_location IS NOT NULL
  AND location_id   <> prev_location
  AND EXTRACT(EPOCH FROM (timestamp - prev_timestamp)) / 60 < 60  -- less than 60 min
ORDER BY user_id, timestamp;


-- ============================================================
-- INDICATOR B — TRANSACTION BURST
-- ≥ 5 transactions by the same user within any 10-minute window
-- ============================================================
WITH windowed AS (
    SELECT
        user_id,
        transaction_id,
        timestamp,
        amount,
        COUNT(*) OVER (
            PARTITION BY user_id
            ORDER BY timestamp
            RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW
        ) AS txn_in_10min
    FROM transactions
)
SELECT
    user_id,
    COUNT(*)                          AS burst_transactions,
    MIN(timestamp)                    AS window_start,
    MAX(timestamp)                    AS window_end,
    ROUND(SUM(amount) / 1e6, 2)      AS total_amount_million,
    MAX(txn_in_10min)                 AS peak_10min_count
FROM windowed
WHERE txn_in_10min >= 5
GROUP BY user_id
ORDER BY burst_transactions DESC;


-- ============================================================
-- INDICATOR C — REFUND ABUSE
-- Users whose refund rate is ≥ 5× the population average
-- and who have at least 5 total transactions
-- ============================================================
WITH population AS (
    SELECT ROUND(AVG(refund_flag::FLOAT) * 100, 2) AS avg_refund_pct
    FROM transactions
),
user_refund AS (
    SELECT
        user_id,
        COUNT(*)                                                          AS txn_count,
        SUM(refund_flag)                                                  AS refund_count,
        ROUND(100.0 * SUM(refund_flag) / NULLIF(COUNT(*), 0), 2)        AS refund_rate_pct,
        ROUND(SUM(CASE WHEN refund_flag = 1 THEN amount ELSE 0 END)
              / 1e6, 2)                                                   AS refunded_amount_million
    FROM transactions
    GROUP BY user_id
    HAVING COUNT(*) >= 5
)
SELECT
    ur.*,
    p.avg_refund_pct,
    ROUND(ur.refund_rate_pct / NULLIF(p.avg_refund_pct, 0), 1) AS multiple_of_avg
FROM user_refund ur, population p
WHERE ur.refund_rate_pct >= p.avg_refund_pct * 5
ORDER BY ur.refund_rate_pct DESC;


-- ============================================================
-- INDICATOR D — UNUSUAL AMOUNT
-- Transactions exceeding 8× the user's own historical average
-- for the same category
-- ============================================================
WITH user_cat_baseline AS (
    SELECT
        user_id,
        category,
        AVG(amount)    AS avg_amt,
        STDDEV(amount) AS std_amt,
        COUNT(*)       AS history_count
    FROM transactions
    GROUP BY user_id, category
)
SELECT
    t.transaction_id,
    t.user_id,
    t.timestamp,
    t.amount,
    t.category,
    ROUND(b.avg_amt, 0)                                     AS user_cat_avg_idr,
    ROUND(t.amount / NULLIF(b.avg_amt, 0), 1)              AS multiple_of_own_avg,
    t.device_id,
    t.location_id,
    t.payment_method,
    t.refund_flag,
    t.chargeback_flag
FROM transactions t
JOIN user_cat_baseline b
  ON t.user_id = b.user_id
 AND t.category = b.category
WHERE b.history_count >= 3                                  -- need baseline history
  AND t.amount > b.avg_amt * 8
ORDER BY multiple_of_own_avg DESC;


-- ============================================================
-- INDICATOR E — NEW DEVICE + HIGH VALUE
-- First-ever use of a device, combined with a transaction
-- above p95 amount threshold
-- ============================================================
WITH device_first_use AS (
    SELECT
        user_id,
        device_id,
        MIN(timestamp) AS first_used_at
    FROM transactions
    GROUP BY user_id, device_id
),
p95_threshold AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) AS p95
    FROM transactions
)
SELECT
    t.transaction_id,
    t.user_id,
    t.device_id,
    t.timestamp,
    t.amount,
    th.p95             AS p95_threshold_idr,
    ROUND(t.amount / NULLIF(th.p95, 0), 2) AS multiple_of_p95,
    t.category,
    t.location_id,
    t.payment_method,
    t.refund_flag
FROM transactions t
JOIN device_first_use dfu
  ON t.user_id   = dfu.user_id
 AND t.device_id = dfu.device_id
 AND t.timestamp = dfu.first_used_at
CROSS JOIN p95_threshold th
WHERE t.amount > th.p95
ORDER BY t.amount DESC;


-- ============================================================
-- INDICATOR F — SHARED DEVICE
-- A single device_id used by ≥ 2 distinct users
-- ============================================================
WITH shared AS (
    SELECT
        device_id,
        COUNT(DISTINCT user_id)                                       AS user_count,
        STRING_AGG(DISTINCT user_id, ', ' ORDER BY user_id)          AS sharing_users,
        COUNT(transaction_id)                                         AS total_txn,
        ROUND(SUM(amount) / 1e6, 2)                                   AS total_amount_million
    FROM transactions
    GROUP BY device_id
    HAVING COUNT(DISTINCT user_id) >= 2
)
SELECT
    s.*,
    d.device_type,
    d.operating_system
FROM shared s
JOIN devices d ON s.device_id = d.device_id
ORDER BY s.user_count DESC, s.total_amount_million DESC;


-- ============================================================
-- INDICATOR G — UNUSUAL LOCATION
-- Transactions from a city different from the user's home city
-- with amount above the user's 75th percentile
-- ============================================================
WITH user_p75 AS (
    SELECT
        user_id,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS p75_amt
    FROM transactions
    GROUP BY user_id
)
SELECT
    t.transaction_id,
    t.user_id,
    u.city                             AS home_city,
    t.location_id                      AS txn_city,
    t.timestamp,
    t.amount,
    ROUND(up.p75_amt, 0)               AS user_p75_idr,
    ROUND(t.amount / NULLIF(up.p75_amt, 0), 1) AS multiple_of_p75,
    t.device_id,
    t.payment_method,
    t.category,
    t.refund_flag
FROM transactions t
JOIN users u    ON t.user_id = u.user_id
JOIN user_p75 up ON t.user_id = up.user_id
WHERE t.location_id <> u.city
  AND t.amount > up.p75_amt
ORDER BY multiple_of_p75 DESC;


-- ============================================================
-- COMPOSITE: Combined risk score per user
-- Each indicator contributes points; sum = risk score
-- ============================================================
WITH indicator_a AS (
    -- Impossible travel hit
    SELECT DISTINCT user_id, 35 AS score, 'impossible_travel' AS indicator
    FROM (
        SELECT user_id, location_id,
               LAG(location_id) OVER (PARTITION BY user_id ORDER BY timestamp) AS prev_loc,
               EXTRACT(EPOCH FROM (timestamp -
                       LAG(timestamp) OVER (PARTITION BY user_id ORDER BY timestamp))) / 60 AS gap_min
        FROM transactions
    ) x
    WHERE prev_loc IS NOT NULL AND location_id <> prev_loc AND gap_min < 60
),
indicator_b AS (
    -- Burst transactions hit
    SELECT DISTINCT user_id, 25 AS score, 'transaction_burst' AS indicator
    FROM (
        SELECT user_id,
               COUNT(*) OVER (PARTITION BY user_id ORDER BY timestamp
                              RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW) AS cnt
        FROM transactions
    ) w WHERE cnt >= 5
),
indicator_c AS (
    -- Refund abuse
    SELECT user_id, 20 AS score, 'refund_abuse' AS indicator
    FROM (
        SELECT user_id,
               100.0 * SUM(refund_flag) / NULLIF(COUNT(*), 0) AS rr,
               (SELECT 100.0 * AVG(refund_flag::FLOAT) FROM transactions) AS avg_rr
        FROM transactions GROUP BY user_id HAVING COUNT(*) >= 5
    ) r WHERE rr >= avg_rr * 5
),
indicator_d AS (
    SELECT DISTINCT t.user_id, 20 AS score, 'unusual_amount' AS indicator
    FROM transactions t
    JOIN (SELECT user_id, category, AVG(amount) AS a FROM transactions GROUP BY 1,2) b
      ON t.user_id = b.user_id AND t.category = b.category
    WHERE t.amount > b.a * 8
),
indicator_e AS (
    SELECT DISTINCT t.user_id, 20 AS score, 'new_device_high_value' AS indicator
    FROM transactions t
    JOIN (SELECT user_id, device_id, MIN(timestamp) AS ft FROM transactions GROUP BY 1,2) dfu
      ON t.user_id = dfu.user_id AND t.device_id = dfu.device_id AND t.timestamp = dfu.ft
    WHERE t.amount > (SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) FROM transactions)
),
indicator_f AS (
    SELECT DISTINCT t.user_id, 15 AS score, 'shared_device' AS indicator
    FROM transactions t
    WHERE t.device_id IN (
        SELECT device_id FROM transactions GROUP BY device_id HAVING COUNT(DISTINCT user_id) >= 2
    )
),
indicator_g AS (
    SELECT DISTINCT t.user_id, 10 AS score, 'unusual_location' AS indicator
    FROM transactions t
    JOIN users u ON t.user_id = u.user_id
    JOIN (SELECT user_id, PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS p75
          FROM transactions GROUP BY user_id) up ON t.user_id = up.user_id
    WHERE t.location_id <> u.city AND t.amount > up.p75
),
all_indicators AS (
    SELECT * FROM indicator_a
    UNION ALL SELECT * FROM indicator_b
    UNION ALL SELECT * FROM indicator_c
    UNION ALL SELECT * FROM indicator_d
    UNION ALL SELECT * FROM indicator_e
    UNION ALL SELECT * FROM indicator_f
    UNION ALL SELECT * FROM indicator_g
)
SELECT
    ai.user_id,
    u.username,
    STRING_AGG(ai.indicator, ' | ' ORDER BY ai.score DESC) AS triggered_indicators,
    SUM(ai.score)                                           AS composite_risk_score,
    CASE WHEN SUM(ai.score) >= 61 THEN 'HIGH'
         WHEN SUM(ai.score) >= 31 THEN 'MEDIUM'
         ELSE                          'LOW'
    END                                                     AS risk_level
FROM all_indicators ai
JOIN users u ON ai.user_id = u.user_id
GROUP BY ai.user_id, u.username
ORDER BY composite_risk_score DESC;
