-- =============================================================================
-- 02_TRANSACTION_ANALYSIS.SQL
-- Digital Crime Investigation — Transaction Fraud & Anomaly Analytics
-- Phase 2: Transaction Pattern & Baseline Analysis
-- =============================================================================

-- ------------------------------------------------------------
-- 2.1  Transaction volume by month
-- ------------------------------------------------------------
SELECT
    TO_CHAR(timestamp, 'YYYY-MM') AS month,
    COUNT(*)                       AS total_txn,
    COUNT(DISTINCT user_id)        AS unique_users,
    ROUND(SUM(amount) / 1e6, 2)   AS total_amount_million_idr,
    ROUND(AVG(amount), 0)          AS avg_amount_idr
FROM transactions
GROUP BY TO_CHAR(timestamp, 'YYYY-MM')
ORDER BY month;


-- ------------------------------------------------------------
-- 2.2  Transaction volume by day of week and hour of day
-- ------------------------------------------------------------
SELECT
    TO_CHAR(timestamp, 'Day') AS day_of_week,
    EXTRACT(DOW FROM timestamp)::INT AS dow_num,
    COUNT(*)                   AS txn_count,
    ROUND(AVG(amount), 0)      AS avg_amount
FROM transactions
GROUP BY TO_CHAR(timestamp, 'Day'), EXTRACT(DOW FROM timestamp)
ORDER BY dow_num;

-- Hourly pattern (identify off-hours spikes)
SELECT
    EXTRACT(HOUR FROM timestamp)::INT AS hour_of_day,
    COUNT(*)                          AS txn_count,
    ROUND(AVG(amount), 0)             AS avg_amount,
    SUM(CASE WHEN refund_flag = 1 THEN 1 ELSE 0 END) AS refund_count
FROM transactions
GROUP BY EXTRACT(HOUR FROM timestamp)
ORDER BY hour_of_day;


-- ------------------------------------------------------------
-- 2.3  Amount distribution by category
-- ------------------------------------------------------------
SELECT
    category,
    COUNT(*)                                                  AS txn_count,
    ROUND(MIN(amount), 0)                                     AS min_idr,
    ROUND(MAX(amount), 0)                                     AS max_idr,
    ROUND(AVG(amount), 0)                                     AS avg_idr,
    ROUND(STDDEV(amount), 0)                                  AS stddev_idr,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP
          (ORDER BY amount), 0)                               AS median_idr,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP
          (ORDER BY amount), 0)                               AS p95_idr
FROM transactions
GROUP BY category
ORDER BY avg_idr DESC;


-- ------------------------------------------------------------
-- 2.4  Payment method share and fraud signal
-- ------------------------------------------------------------
SELECT
    payment_method,
    COUNT(*)                                                    AS total_txn,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)         AS share_pct,
    SUM(CASE WHEN refund_flag = 1     THEN 1 ELSE 0 END)       AS refunds,
    SUM(CASE WHEN chargeback_flag = 1 THEN 1 ELSE 0 END)       AS chargebacks,
    ROUND(100.0 * SUM(CASE WHEN refund_flag = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                             AS refund_rate_pct,
    ROUND(AVG(amount), 0)                                       AS avg_amount_idr
FROM transactions
GROUP BY payment_method
ORDER BY total_txn DESC;


-- ------------------------------------------------------------
-- 2.5  Status breakdown
-- ------------------------------------------------------------
SELECT
    transaction_status,
    COUNT(*)                                                        AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)             AS pct,
    ROUND(SUM(amount) / 1e6, 2)                                     AS total_amount_million
FROM transactions
GROUP BY transaction_status
ORDER BY count DESC;


-- ------------------------------------------------------------
-- 2.6  Top 10 merchants by volume and refund rate
-- ------------------------------------------------------------
SELECT
    m.merchant_id,
    m.merchant_name,
    m.category,
    m.city,
    COUNT(t.transaction_id)                                          AS txn_count,
    ROUND(SUM(t.amount) / 1e6, 2)                                   AS total_amount_million,
    SUM(CASE WHEN t.refund_flag = 1     THEN 1 ELSE 0 END)          AS refunds,
    ROUND(100.0 * SUM(CASE WHEN t.refund_flag = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(t.transaction_id), 0), 2)                   AS refund_rate_pct
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category, m.city
ORDER BY total_amount_million DESC
LIMIT 10;


-- ------------------------------------------------------------
-- 2.7  Geographic concentration — city-level heatmap
-- ------------------------------------------------------------
SELECT
    location_id                                           AS city,
    COUNT(*)                                              AS txn_count,
    COUNT(DISTINCT user_id)                               AS unique_users,
    ROUND(SUM(amount) / 1e6, 2)                           AS total_amount_million,
    SUM(CASE WHEN refund_flag = 1 THEN 1 ELSE 0 END)     AS refunds,
    ROUND(100.0 * SUM(CASE WHEN refund_flag = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                       AS refund_rate_pct
FROM transactions
GROUP BY location_id
ORDER BY txn_count DESC;


-- ------------------------------------------------------------
-- 2.8  High-value transaction threshold (p99 baseline)
-- ------------------------------------------------------------
WITH baseline AS (
    SELECT
        category,
        AVG(amount)    AS avg_amt,
        STDDEV(amount) AS std_amt,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amount) AS p99_amt
    FROM transactions
    GROUP BY category
)
SELECT
    t.transaction_id,
    t.user_id,
    t.timestamp,
    t.amount,
    t.category,
    b.avg_amt,
    b.p99_amt,
    ROUND(t.amount / NULLIF(b.avg_amt, 0), 1) AS multiple_of_avg
FROM transactions t
JOIN baseline b ON t.category = b.category
WHERE t.amount > b.p99_amt
ORDER BY multiple_of_avg DESC;
