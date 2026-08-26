-- =============================================================================
-- 05_INVESTIGATION_CASES.SQL
-- Digital Crime Investigation — Transaction Fraud & Anomaly Analytics
-- Phase 5: Deep-Dive Investigation — Named Cases & Evidence Chains
-- =============================================================================

-- ============================================================
-- CASE-001: IMPOSSIBLE TRAVEL — U0023 (Jakarta → Singapore in 14 min)
-- ============================================================
-- Evidence chain
SELECT
    t.transaction_id,
    t.user_id,
    t.timestamp,
    t.amount,
    t.location_id,
    t.device_id,
    d.device_type,
    d.operating_system,
    t.merchant_id,
    m.merchant_name,
    t.category,
    t.payment_method,
    t.transaction_status,
    t.refund_flag,
    t.chargeback_flag
FROM transactions t
JOIN devices   d ON t.device_id   = d.device_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.user_id = 'U0023'
ORDER BY t.timestamp;

-- Time gap calculation
SELECT
    transaction_id,
    user_id,
    timestamp,
    location_id,
    EXTRACT(EPOCH FROM (timestamp -
            LAG(timestamp) OVER (ORDER BY timestamp))) / 60 AS minutes_since_prev,
    LAG(location_id) OVER (ORDER BY timestamp)               AS previous_city
FROM transactions
WHERE user_id = 'U0023'
ORDER BY timestamp;


-- ============================================================
-- CASE-002: IMPOSSIBLE TRAVEL — U0067 (Bandung → Singapore in 13 min)
-- ============================================================
SELECT
    t.transaction_id,
    t.user_id,
    t.timestamp,
    t.amount,
    t.location_id,
    t.device_id,
    t.payment_method,
    t.refund_flag
FROM transactions t
WHERE t.user_id = 'U0067'
ORDER BY t.timestamp;


-- ============================================================
-- CASE-003: MULTI-HOP IMPOSSIBLE TRAVEL — U0112
--           Surabaya → Bali → Singapore (3 cities, 27 min)
-- ============================================================
SELECT
    t.transaction_id,
    t.user_id,
    t.timestamp,
    t.location_id,
    t.amount,
    t.device_id,
    t.refund_flag,
    EXTRACT(EPOCH FROM (timestamp -
            LAG(timestamp) OVER (ORDER BY timestamp))) / 60 AS min_since_prev
FROM transactions t
WHERE t.user_id = 'U0112'
ORDER BY t.timestamp;


-- ============================================================
-- CASE-004: TRANSACTION BURST — U0045 (6 × Rp500K in 6 min)
-- ============================================================
SELECT
    transaction_id,
    user_id,
    timestamp,
    amount,
    merchant_id,
    category,
    device_id,
    payment_method,
    EXTRACT(EPOCH FROM (timestamp -
            LAG(timestamp) OVER (ORDER BY timestamp))) AS sec_since_prev
FROM transactions
WHERE user_id = 'U0045'
  AND timestamp BETWEEN '2024-02-14 00:59:00' AND '2024-02-14 01:10:00'
ORDER BY timestamp;

-- U0089 burst
SELECT
    transaction_id,
    user_id,
    timestamp,
    amount,
    merchant_id,
    device_id,
    payment_method
FROM transactions
WHERE user_id = 'U0089'
  AND timestamp BETWEEN '2024-05-20 03:10:00' AND '2024-05-20 03:25:00'
ORDER BY timestamp;


-- ============================================================
-- CASE-005: REFUND ABUSE — U0034, U0078, U0156
-- ============================================================
SELECT
    user_id,
    COUNT(*)                                                             AS total_txn,
    SUM(refund_flag)                                                     AS refund_count,
    SUM(chargeback_flag)                                                 AS chargeback_count,
    ROUND(100.0 * SUM(refund_flag) / NULLIF(COUNT(*), 0), 1)           AS refund_rate_pct,
    ROUND(SUM(CASE WHEN refund_flag = 1 THEN amount ELSE 0 END) / 1e6, 2) AS refunded_million_idr,
    ROUND(SUM(amount) / 1e6, 2)                                          AS total_spent_million
FROM transactions
WHERE user_id IN ('U0034', 'U0078', 'U0156')
GROUP BY user_id
ORDER BY refund_rate_pct DESC;

-- Refunded transactions detail for worst offender
SELECT
    transaction_id,
    timestamp,
    amount,
    merchant_id,
    category,
    location_id,
    payment_method,
    refund_flag,
    chargeback_flag
FROM transactions
WHERE user_id = 'U0156'
  AND refund_flag = 1
ORDER BY amount DESC;


-- ============================================================
-- CASE-006: UNUSUAL AMOUNT — U0103 (10.9M & 13.2M vs normal avg)
-- ============================================================
-- Baseline for this user
SELECT
    user_id,
    category,
    COUNT(*)          AS txn_count,
    ROUND(AVG(amount), 0) AS avg_idr,
    ROUND(MIN(amount), 0) AS min_idr,
    ROUND(MAX(amount), 0) AS max_idr
FROM transactions
WHERE user_id = 'U0103'
GROUP BY user_id, category;

-- The anomalous transactions
SELECT
    transaction_id,
    user_id,
    timestamp,
    amount,
    category,
    location_id,
    device_id,
    payment_method,
    refund_flag
FROM transactions
WHERE user_id = 'U0103'
ORDER BY amount DESC;


-- ============================================================
-- CASE-007: NEW DEVICE + HIGH VALUE — D0140–D0143
-- ============================================================
SELECT
    t.transaction_id,
    t.user_id,
    t.device_id,
    t.timestamp,
    t.amount,
    t.location_id,
    t.merchant_id,
    m.merchant_name,
    t.payment_method,
    t.refund_flag,
    d.device_type,
    d.operating_system,
    d.first_seen,
    d.last_seen
FROM transactions t
JOIN devices   d ON t.device_id   = d.device_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.device_id IN ('D0140', 'D0141', 'D0142', 'D0143')
ORDER BY t.device_id, t.timestamp;

-- Compare with prior device history for the same users
SELECT
    t.user_id,
    COUNT(DISTINCT t.device_id)                              AS total_devices,
    SUM(CASE WHEN t.device_id IN ('D0140','D0141','D0142','D0143')
             THEN 1 ELSE 0 END)                              AS new_device_txn,
    SUM(CASE WHEN t.device_id NOT IN ('D0140','D0141','D0142','D0143')
             THEN 1 ELSE 0 END)                              AS prior_device_txn
FROM transactions t
WHERE t.user_id IN ('U0033', 'U0071', 'U0118', 'U0162')
GROUP BY t.user_id;


-- ============================================================
-- CASE-008: SHARED DEVICE — D0150 (4 accounts) & D0151 (5 accounts)
-- ============================================================
SELECT
    t.device_id,
    d.device_type,
    d.operating_system,
    t.user_id,
    t.transaction_id,
    t.timestamp,
    t.amount,
    t.location_id,
    t.payment_method,
    t.refund_flag
FROM transactions t
JOIN devices d ON t.device_id = d.device_id
WHERE t.device_id IN ('D0150', 'D0151')
ORDER BY t.device_id, t.timestamp;

-- User overlap summary
SELECT
    device_id,
    COUNT(DISTINCT user_id)                                    AS sharing_accounts,
    STRING_AGG(DISTINCT user_id, ', ' ORDER BY user_id)       AS account_list,
    COUNT(transaction_id)                                      AS total_txn,
    ROUND(SUM(amount) / 1e6, 2)                                AS total_amount_million
FROM transactions
WHERE device_id IN ('D0150', 'D0151')
GROUP BY device_id;


-- ============================================================
-- MASTER CASE REGISTER — All flagged users with evidence summary
-- ============================================================
WITH flagged AS (
    SELECT 'U0023' AS user_id, 'Impossible Travel' AS case_type, 'CASE-001' AS case_id UNION ALL
    SELECT 'U0067', 'Impossible Travel',    'CASE-002' UNION ALL
    SELECT 'U0112', 'Impossible Travel',    'CASE-003' UNION ALL
    SELECT 'U0045', 'Transaction Burst',    'CASE-004' UNION ALL
    SELECT 'U0089', 'Transaction Burst',    'CASE-004' UNION ALL
    SELECT 'U0034', 'Refund Abuse',         'CASE-005' UNION ALL
    SELECT 'U0078', 'Refund Abuse',         'CASE-005' UNION ALL
    SELECT 'U0156', 'Refund Abuse',         'CASE-005' UNION ALL
    SELECT 'U0019', 'Unusual Amount',       'CASE-006' UNION ALL
    SELECT 'U0057', 'Unusual Amount',       'CASE-006' UNION ALL
    SELECT 'U0103', 'Unusual Amount',       'CASE-006' UNION ALL
    SELECT 'U0144', 'Unusual Amount',       'CASE-006' UNION ALL
    SELECT 'U0191', 'Unusual Amount',       'CASE-006' UNION ALL
    SELECT 'U0033', 'New Device High Value','CASE-007' UNION ALL
    SELECT 'U0071', 'New Device High Value','CASE-007' UNION ALL
    SELECT 'U0118', 'New Device High Value','CASE-007' UNION ALL
    SELECT 'U0162', 'New Device High Value','CASE-007' UNION ALL
    SELECT 'U0041', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0082', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0133', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0177', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0015', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0066', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0099', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0155', 'Shared Device',        'CASE-008' UNION ALL
    SELECT 'U0188', 'Shared Device',        'CASE-008'
)
SELECT
    f.case_id,
    f.user_id,
    u.username,
    f.case_type,
    u.city,
    u.account_age_days,
    COUNT(t.transaction_id)                                            AS total_txn,
    ROUND(SUM(t.amount) / 1e6, 2)                                     AS total_million_idr,
    SUM(t.refund_flag)                                                 AS refunds,
    SUM(t.chargeback_flag)                                             AS chargebacks,
    ROUND(100.0 * SUM(t.refund_flag) / NULLIF(COUNT(t.transaction_id), 0), 1) AS refund_pct
FROM flagged f
JOIN users        u ON f.user_id = u.user_id
LEFT JOIN transactions t ON f.user_id = t.user_id
GROUP BY f.case_id, f.user_id, u.username, f.case_type, u.city, u.account_age_days
ORDER BY f.case_id, f.user_id;
