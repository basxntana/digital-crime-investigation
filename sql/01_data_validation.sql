-- =============================================================================
-- 01_DATA_VALIDATION.SQL
-- Digital Crime Investigation — Transaction Fraud & Anomaly Analytics
-- Phase 1: Data Quality & Integrity Checks
-- =============================================================================

-- ------------------------------------------------------------
-- 1.1  Row counts per table
-- ------------------------------------------------------------
SELECT 'transactions' AS table_name, COUNT(*) AS row_count FROM transactions
UNION ALL
SELECT 'users',        COUNT(*) FROM users
UNION ALL
SELECT 'devices',      COUNT(*) FROM devices
UNION ALL
SELECT 'merchants',    COUNT(*) FROM merchants;


-- ------------------------------------------------------------
-- 1.2  Null / blank checks — transactions
-- ------------------------------------------------------------
SELECT
    COUNT(*)                                          AS total_rows,
    SUM(CASE WHEN transaction_id  IS NULL THEN 1 ELSE 0 END) AS null_txn_id,
    SUM(CASE WHEN user_id         IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN timestamp       IS NULL THEN 1 ELSE 0 END) AS null_timestamp,
    SUM(CASE WHEN amount          IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN merchant_id     IS NULL THEN 1 ELSE 0 END) AS null_merchant_id,
    SUM(CASE WHEN location_id     IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN device_id       IS NULL THEN 1 ELSE 0 END) AS null_device_id,
    SUM(CASE WHEN payment_method  IS NULL THEN 1 ELSE 0 END) AS null_payment_method,
    SUM(CASE WHEN transaction_status IS NULL THEN 1 ELSE 0 END) AS null_status
FROM transactions;


-- ------------------------------------------------------------
-- 1.3  Duplicate transaction IDs
-- ------------------------------------------------------------
SELECT transaction_id, COUNT(*) AS occurrences
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;


-- ------------------------------------------------------------
-- 1.4  Referential integrity — orphan foreign keys
-- ------------------------------------------------------------
-- Users not found in users table
SELECT t.user_id
FROM transactions t
LEFT JOIN users u ON t.user_id = u.user_id
WHERE u.user_id IS NULL
GROUP BY t.user_id;

-- Devices not found in devices table
SELECT t.device_id
FROM transactions t
LEFT JOIN devices d ON t.device_id = d.device_id
WHERE d.device_id IS NULL
GROUP BY t.device_id;

-- Merchants not found in merchants table
SELECT t.merchant_id
FROM transactions t
LEFT JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE m.merchant_id IS NULL
GROUP BY t.merchant_id;


-- ------------------------------------------------------------
-- 1.5  Amount range check (negative or implausibly small)
-- ------------------------------------------------------------
SELECT
    MIN(amount)                          AS min_amount,
    MAX(amount)                          AS max_amount,
    AVG(amount)                          AS avg_amount,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY amount) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS p75,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) AS p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amount) AS p99,
    SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END)         AS non_positive_count
FROM transactions;


-- ------------------------------------------------------------
-- 1.6  Valid categorical values
-- ------------------------------------------------------------
-- transaction_status
SELECT transaction_status, COUNT(*) AS cnt
FROM transactions
GROUP BY transaction_status
ORDER BY cnt DESC;

-- payment_method
SELECT payment_method, COUNT(*) AS cnt
FROM transactions
GROUP BY payment_method
ORDER BY cnt DESC;

-- category
SELECT category, COUNT(*) AS cnt
FROM transactions
GROUP BY category
ORDER BY cnt DESC;


-- ------------------------------------------------------------
-- 1.7  Date range sanity check
-- ------------------------------------------------------------
SELECT
    MIN(timestamp) AS earliest_transaction,
    MAX(timestamp) AS latest_transaction,
    COUNT(DISTINCT DATE(timestamp)) AS active_days
FROM transactions;


-- ------------------------------------------------------------
-- 1.8  refund_flag / chargeback_flag consistency
--      A chargeback with no refund is unusual; flag for review
-- ------------------------------------------------------------
SELECT
    SUM(CASE WHEN refund_flag = 1                          THEN 1 ELSE 0 END) AS total_refunds,
    SUM(CASE WHEN chargeback_flag = 1                      THEN 1 ELSE 0 END) AS total_chargebacks,
    SUM(CASE WHEN refund_flag = 0 AND chargeback_flag = 1  THEN 1 ELSE 0 END) AS chargeback_no_refund,
    SUM(CASE WHEN refund_flag = 1 AND chargeback_flag = 1  THEN 1 ELSE 0 END) AS both_flags
FROM transactions;


-- ------------------------------------------------------------
-- 1.9  Device first_seen / last_seen sanity
-- ------------------------------------------------------------
SELECT *
FROM devices
WHERE last_seen < first_seen
   OR first_seen IS NULL
   OR last_seen  IS NULL;


-- ------------------------------------------------------------
-- 1.10 Summary quality score
-- ------------------------------------------------------------
WITH checks AS (
    SELECT
        (SELECT COUNT(*) FROM transactions)                               AS total_txn,
        (SELECT COUNT(*) FROM transactions WHERE amount <= 0)             AS bad_amount,
        (SELECT COUNT(*) FROM (
            SELECT transaction_id FROM transactions
            GROUP BY transaction_id HAVING COUNT(*) > 1
        ) d)                                                              AS dup_txn,
        (SELECT COUNT(*) FROM transactions t
         LEFT JOIN users u ON t.user_id = u.user_id
         WHERE u.user_id IS NULL)                                         AS orphan_users
)
SELECT
    total_txn,
    bad_amount,
    dup_txn,
    orphan_users,
    ROUND(100.0 * (total_txn - bad_amount - dup_txn - orphan_users)
          / NULLIF(total_txn, 0), 2)                                      AS quality_score_pct
FROM checks;
