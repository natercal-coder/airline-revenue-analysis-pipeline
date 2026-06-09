# XA Airways — Revenue Analysis Pipeline

An end-to-end revenue analytics framework built with **PostgreSQL** and **Power BI**, covering primary revenue, ancillary revenue, booking behavior, and data quality monitoring for a commercial airline operation.

> **Note:** All data in this repository is fully synthetic. Route codes, booking classes, agent codes, payment methods, and financial figures have been anonymized. The pipeline architecture, schema design, and dashboard logic reflect real-world implementation patterns.

---

## Overview

| Item | Detail |
|---|---|
| Tools | PostgreSQL 14, Power BI Desktop |
| Data sources | 4 CSV feeds loaded monthly |
| Dashboard pages | 6 (Revenue Summary, Route Intelligence, Booking Behavior, Deep Dive, Ancillary Analysis, Data Quality) |
| Records processed | ~2,000 primary + ~1,100 ancillary documents (synthetic) |
| Schedule | Monthly batch load |

---

## Repository structure

```
.
├── generate_synthetic_data.py    # Python script to generate synthetic CSV data
├── load_month_data.sql           # PostgreSQL monthly load pipeline
├── revenue_primary_202512.csv    # Synthetic primary revenue data (Dec 2025)
├── ancillary_doc_a_202512.csv    # Synthetic ancillary — doc type A
├── ancillary_doc_s_202512.csv    # Synthetic ancillary — doc type S
├── ancillary_noshow_202512.csv   # Synthetic ancillary — no-show documents
└── README.md
```

---

## Data sources

### 1. Primary revenue (`stg_revenue_primary`)
Core revenue data. Each row represents one issued document.

| Column | Description |
|---|---|
| `carrier_code` | Airline identifier |
| `service_date` | Scheduled service date |
| `area_type` | Route type — DOM or INT |
| `route_code` | Origin-destination pair |
| `booking_class` | Booking class (Class 1–9) |
| `payment_method` | Form of payment |
| `revenue_category` | Revenue segment category |
| `agent_code` | Issuing agent |
| `base_fare_local` | Base fare in local currency |
| `total_fare_usd` | Total revenue in USD |
| `fare_basis_code` | Fare basis reference |
| `issue_date` | Document issue date |
| `period` | Load period (month) |

### 2. Ancillary doc type A (`stg_ancillary_doc_a`)
Ancillary revenue documents — covers pre-booked ancillary services.

### 3. Ancillary doc type S (`stg_ancillary_doc_s`)
Standalone ancillary documents — covers post-booking service additions.

### 4. Ancillary no-show (`stg_ancillary_noshow`)
No-show fee documents — passengers who did not board their booked flight.

---

## Pipeline architecture

```
CSV files (monthly)
        │
        ▼
  Temp tables (PostgreSQL)
  tmp_primary_src / tmp_ancillary_src
        │
        ▼
  Staging tables (xa_rev schema)
  stg_revenue_primary
  stg_ancillary_doc_a / stg_ancillary_doc_s / stg_ancillary_noshow
        │
        ├── Null normalization (UPDATE statements)
        ├── Duplicate detection
        └── Anomaly flagging
                │
                ▼
          Power BI (DirectQuery / Import)
                │
        ┌───────┼───────────────┐
        ▼       ▼               ▼
  Revenue   Ancillary     Data Quality
  Summary   Analysis       Monitor
```

---

## SQL pipeline — key design decisions

### Safe monthly reload pattern
Each load cycle deletes the target period before inserting, preventing duplicate rows without a full table truncate:

```sql
DELETE FROM xa_rev.stg_revenue_primary
WHERE period = DATE '2025-12-01';
```

### Temp table staging
Raw CSV data lands in a `TEMP TABLE` first — all columns as `text` — allowing type-agnostic ingestion before casting on insert:

```sql
CREATE TEMP TABLE tmp_primary_src (
    carrier_code text, service_date text, ...
) ON COMMIT DROP;

\copy tmp_primary_src FROM :'p_primary'
    WITH (FORMAT csv, HEADER true, ...);
```

### Null normalization
Dirty null representations from source systems are standardized to SQL `NULL` after load:

```sql
UPDATE xa_rev.stg_ancillary_doc_a
SET base_fare_usd = NULL
WHERE UPPER(TRIM(base_fare_usd)) IN ('NULL','N/A','-','#N/A');
```

### Row count validation
A `UNION ALL` query at the end confirms row counts per source and period — lightweight data contract check:

```sql
SELECT src, period, COUNT(*) AS row_count
FROM (
    SELECT 'PRIMARY' AS src, period FROM xa_rev.stg_revenue_primary
    UNION ALL
    SELECT 'DOC_A'   AS src, period FROM xa_rev.stg_ancillary_doc_a
    ...
) t
GROUP BY src, period;
```

---

## Power BI dashboard

### Pages & key metrics

| Page | Key visuals |
|---|---|
| **Revenue summary** | Total revenue, total documents, avg fare, revenue by area type (DOM/INT), revenue by class, top 10 routes, revenue trend |
| **Route & flight intelligence** | Top 10 flight numbers, top routes, flight frequency, flights per day, frequency vs revenue scatter |
| **Booking behavior** | Booking trend, booking vs service date, lead time distribution, revenue by lead time, route behavior |
| **Deep dive performance** | Class performance, agent performance, payment method analysis, avg fare by class, fare basis performance, promo vs non-promo, index performance |
| **Ancillary analysis** | Total ancillary revenue, doc count, avg per doc, ancillary trend, distribution by service type, ancillary by route |
| **Control & data quality** | Duplicate flag, anomaly flag, null revenue count, row count validation per source |

### Filters available
- **Area** — All / DOM / INT
- **Class** — All / Class 1–9
- **Date** — All / specific period
- **Payment method** — All / Payment A / B / C *(Booking Behavior & Deep Dive)*
- **Agent** — All / Agent A1–C2 *(Booking Behavior & Deep Dive)*

---

## How to run

### 1. Generate synthetic data

```bash
pip install pandas numpy
python generate_synthetic_data.py
```

### 2. Set up PostgreSQL schema

```sql
CREATE SCHEMA xa_rev;

CREATE TABLE xa_rev.stg_revenue_primary (
    carrier_code text, service_date date, area_type text,
    route_code text, booking_class text, payment_method text,
    revenue_category text, agent_code text,
    base_fare_local numeric, total_fare_usd numeric,
    fare_basis_code text, issue_date date, period date
);
-- (repeat for stg_ancillary_doc_a, stg_ancillary_doc_s, stg_ancillary_noshow)
```

### 3. Load monthly data

Edit the parameter block at the top of the SQL file:

```sql
\set period    '2025-12-01'
\set p_primary 'path/to/revenue_primary_202512.csv'
\set p_doc_s   'path/to/ancillary_doc_s_202512.csv'
\set p_doc_a   'path/to/ancillary_doc_a_202512.csv'
\set p_noshow  'path/to/ancillary_noshow_202512.csv'
```

Then run:

```bash
psql -U your_user -d your_db -f load_month_data.sql
```

### 4. Connect Power BI
Point the Power BI data source to your PostgreSQL instance and the `xa_rev` schema.

---

## Skills demonstrated

- **PostgreSQL** — schema design, temp tables, transactional batch load, null normalization, row count validation
- **Python** — synthetic data generation with realistic distributions (`pandas`, `numpy`)
- **Power BI** — multi-page dashboard, cross-page filters, DAX measures, data quality monitoring
- **Data engineering** — idempotent monthly load pattern, multi-source staging layer, data contract validation
- **Analytics** — revenue decomposition, ancillary contribution, booking lead time behavior, route performance benchmarking
