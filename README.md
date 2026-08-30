# 🕵️ Digital Crime Investigation
### Transaction Fraud & Anomaly Analytics — Portfolio Project

![Status](https://img.shields.io/badge/Status-Complete-52B788?style=flat-square)
![Role](https://img.shields.io/badge/Role-Data%20Analyst-4CC9F0?style=flat-square)
![Python](https://img.shields.io/badge/Python-3.10-3776AB?style=flat-square&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/PostgreSQL-SQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat-square&logo=powerbi&logoColor=black)

> *"Follow the data. Find the pattern. Investigate the anomaly."*

---

## Overview

**Digital Crime Investigation** adalah project analytics yang mensimulasikan proses investigasi transaksi mencurigakan pada sebuah perusahaan fintech. Data Analyst berperan sebagai **Data Detective** — menggunakan data untuk menemukan pola, menghubungkan bukti, menentukan tingkat risiko, dan menghasilkan rekomendasi bisnis.

**Business Question:**  
> *"What happened to the company's money, and which transaction patterns should be investigated?"*

**Business Scenario:**  
Tim Finance mendeteksi indikasi *financial leakage*: jumlah refund meningkat, beberapa transaksi bernilai ekstrem, aktivitas di jam tidak wajar, dan device yang tidak konsisten. Management meminta Data Analyst untuk melakukan investigasi penuh.

---

## Key Results

| Metric | Value |
|---|---|
| Transactions Analyzed | **433** (Jan–Jun 2024) |
| Users Profiled | **200** aktif |
| Cases Opened | **8 kasus** |
| Accounts Flagged | **28 akun** (14% user base) |
| Anomaly Indicators Used | **7 indicators** (A–G) |
| Potential Loss Exposure | **Rp 87.2 Juta** |
| High Risk Users | **9 users** (score ≥ 61) |

---

## Investigation Cases

| Case ID | Type | Users | Risk |
|---|---|---|---|
| CASE-001 | Impossible Travel | U0023 · Jakarta→Singapore in 14 min | 🔴 HIGH |
| CASE-002 | Impossible Travel | U0067 · Bandung→Singapore in 13 min | 🔴 HIGH |
| CASE-003 | Impossible Travel (Multi-Hop) | U0112 · Surabaya→Bali→Singapore in 27 min | 🔴 HIGH |
| CASE-004 | Transaction Burst | U0045, U0089 · 6× Rp500K in 6 minutes | 🔴 HIGH |
| CASE-005 | Refund Abuse | U0034, U0078, U0156 · 30%+ refund rate | 🔴 HIGH |
| CASE-006 | Unusual Amount | U0019, U0057, U0103, U0144, U0191 · 12–20× avg | 🟠 MEDIUM |
| CASE-007 | New Device + High Value | U0033, U0071, U0118, U0162 · new device >p95 | 🟠 MEDIUM |
| CASE-008 | Shared Device Ring | D0150 (4 accts), D0151 (5 accts) | 🟠 MEDIUM |

---

## Anomaly Indicators & Risk Scoring

| Indicator | Description | Score |
|---|---|---|
| **A** Impossible Travel | Dua lokasi berbeda dalam < 60 menit | +35 |
| **B** Transaction Burst | ≥ 5 transaksi dalam 10 menit | +25 |
| **C** Refund Abuse | Refund rate ≥ 5× rata-rata populasi | +20 |
| **D** Unusual Amount | Transaksi > 8× rata-rata historis user | +20 |
| **E** New Device + High Value | Device baru + transaksi > p95 | +20 |
| **F** Shared Device | 1 device digunakan oleh ≥ 2 akun | +15 |
| **G** Unusual Location | Di luar kota asal + amount > p75 user | +10 |

**Risk Levels:** 🟢 LOW = 0–30 · 🟠 MEDIUM = 31–60 · 🔴 HIGH = 61+

---

## Repository Structure

```
digital-crime-investigation/
│
├── data/
│   ├── transactions.csv              # Transaction records
│   ├── users.csv                     # User profiles
│   ├── devices.csv                   # Device records
│   └── merchants.csv                 # Merchant records
│
├── sql/
│   ├── 01_data_validation.sql        # Data quality & integrity checks
│   ├── 02_transaction_analysis.sql   # Transaction trends & patterns
│   ├── 03_user_behavior.sql          # User profiling & behavior analysis
│   ├── 04_anomaly_analysis.sql       # Anomaly indicators & risk scoring
│   └── 05_investigation_cases.sql    # Investigation cases & evidence chains
│
├── notebooks/
│   └── full_investigation.ipynb      # End-to-end data cleaning, EDA & investigation
│
├── dashboard/
│   ├── digital-crime-investigation.pbix  # Power BI investigation dashboard
│   └── dashboard_spec.html                # Dashboard design & specification
│
├── reports/
│   └── investigation_report.html     # Final investigation report
│
├── images/
│   └── ...                            # Dashboard & analysis visualizations
│
├── index.html                         # Interactive project case study
├── README.md                          # Project documentation
└── .gitignore
```

---

## Analytics Pipeline

```
Raw Dataset (4 CSV tables)
    │
    ├─ Phase 1 · Data Understanding & Cleaning
    │       → sql/01_data_validation.sql
    │       → notebooks/full_investigation.ipynb
    │
    ├─ Phase 2 · Baseline Analysis
    │       → sql/02_transaction_analysis.sql
    │       → notebooks/full_investigation.ipynb
    │
    ├─ Phase 3 · User Profiling
    │       → sql/03_user_behavior.sql
    │       → notebooks/full_investigation.ipynb
    │
    ├─ Phase 4 · Anomaly Detection
    │       → sql/04_anomaly_analysis.sql
    │       → notebooks/full_investigation.ipynb
    │
    ├─ Phase 5 · Case Investigation
    │       → sql/05_investigation_cases.sql
    │       → notebooks/full_investigation.ipynb
    │
    ├─ Phase 6 · Dashboard
    │       → dashboard/digital-crime-investigation.pbix
    │       → dashboard/dashboard_spec.html
    │
    └─ Phase 7 · Final Report
            → reports/investigation_report.html
```

---

## Dataset Schema

<details>
<summary><strong>transactions</strong> — 433 rows</summary>

| Column | Type | Description |
|---|---|---|
| transaction_id | STRING | ID unik transaksi |
| user_id | STRING | ID user |
| timestamp | DATETIME | Waktu transaksi |
| amount | FLOAT | Nominal (IDR) |
| merchant_id | STRING | ID merchant |
| category | STRING | food_beverage / e-commerce / transfer / retail / bills / travel / gaming / entertainment |
| location_id | STRING | Kota transaksi |
| device_id | STRING | Device yang digunakan |
| payment_method | STRING | credit_card / debit_card / e-wallet / bank_transfer |
| transaction_status | STRING | completed / pending / failed |
| refund_flag | INT | 1 = refund diajukan |
| chargeback_flag | INT | 1 = chargeback terjadi |

</details>

<details>
<summary><strong>users</strong> — 200 rows</summary>

| Column | Type | Description |
|---|---|---|
| user_id | STRING | ID unik user |
| username | STRING | Nama user |
| registration_date | DATE | Tanggal registrasi |
| age_group | STRING | Kelompok usia |
| city | STRING | Kota domisili |
| account_status | STRING | active / suspended |
| account_age_days | INT | Usia akun dalam hari |
| risk_score | INT | Baseline risk score |

</details>

<details>
<summary><strong>devices</strong> — 160 rows</summary>

| Column | Type | Description |
|---|---|---|
| device_id | STRING | ID unik device |
| device_type | STRING | Mobile / Tablet / Desktop |
| operating_system | STRING | iOS / Android / Windows |
| first_seen | DATETIME | Pertama kali digunakan |
| last_seen | DATETIME | Terakhir kali digunakan |

</details>

<details>
<summary><strong>merchants</strong> — 80 rows</summary>

| Column | Type | Description |
|---|---|---|
| merchant_id | STRING | ID unik merchant |
| merchant_name | STRING | Nama merchant |
| category | STRING | Kategori bisnis |
| city | STRING | Kota merchant |

</details>

---

## Tech Stack

| Layer | Technology |
|---|---|
| Data Processing | Python 3.10 · Pandas · NumPy · Matplotlib · Seaborn |
| Database & Query | PostgreSQL · SQL (5 query files) |
| Analysis | Jupyter Notebook (3 notebooks) |
| Visualization | Power BI (4-page dashboard) |
| Version Control | Git · GitHub |

---

## Deliverables

- [x] Synthetic dataset — 4 CSV tables, 433 transactions, 7 planted anomaly types
- [x] SQL investigation — 5 query files covering all 6 analysis phases
- [x] Python notebooks — data cleaning, EDA, anomaly detection
- [x] Anomaly detection — 7 indicators (A–G) with composite risk scoring
- [x] Investigation cases — 8 named cases with evidence chains
- [x] Power BI dashboard specification — 4-page layout with DAX measures
- [x] Investigation report — formal HTML report with findings & recommendations
- [x] Business recommendations — 6 prioritized action items

---

## Important Analytical Note

> Project ini **tidak bertujuan menyatakan seseorang sebagai pelaku fraud**.
> Analisis digunakan untuk menemukan pola tidak biasa, memprioritaskan investigasi, mengidentifikasi potential risk, dan membantu proses pengambilan keputusan. *Final fraud determination tetap membutuhkan proses investigasi dan verifikasi lebih lanjut.*

---

## Future Roadmap

**Phase 2 — Advanced Analytics**
- User behavior segmentation
- Network/graph analysis (account ring detection)
- Time-series anomaly analysis
- Statistical anomaly detection (Z-score, IQR)

**Phase 3 — Machine Learning** *(out of scope for DA portfolio)*
- Feature engineering from derived risk signals
- Random Forest / XGBoost fraud classifier
- Fraud probability scoring model

---

## Portfolio Narrative

Project ini dipresentasikan bukan sebagai *"Saya membuat dashboard fraud"*, tetapi sebagai:

> *"A fintech company suspected financial leakage. I was tasked to investigate transaction data, identify abnormal behavioral patterns across 7 anomaly dimensions, quantify potential financial exposure at Rp 87.2M, and provide 6 prioritized business recommendations — from immediate account freezes to geo-velocity blocking rules."*

---

**Baskara Kresna Juniarto** · Data Analyst Portfolio · 2024
