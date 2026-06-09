\set ON_ERROR_STOP on

ROLLBACK;

BEGIN;

-- =========================
-- PARAMETER — UPDATE EACH PERIOD
-- =========================
\set period        '2025-12-01'
\set p_primary     'path/to/revenue_primary_202512.csv'
\set p_doc_s       'path/to/ancillary_doc_s_202512.csv'
\set p_doc_a       'path/to/ancillary_doc_a_202512.csv'
\set p_noshow      'path/to/ancillary_noshow_202512.csv'

-- =========================
-- PREVENT DUPLICATE — DELETE PERIOD FIRST
-- =========================
DELETE FROM xa_rev.stg_revenue_primary   WHERE period = DATE '2025-12-01';
DELETE FROM xa_rev.stg_ancillary_doc_s   WHERE period = DATE '2025-12-01';
DELETE FROM xa_rev.stg_ancillary_doc_a   WHERE period = DATE '2025-12-01';
DELETE FROM xa_rev.stg_ancillary_noshow  WHERE period = DATE '2025-12-01';

-- =========================
-- TEMP TABLE: PRIMARY REVENUE
-- =========================
CREATE TEMP TABLE tmp_primary_src (
    carrier_code       text,
    service_date       text,
    area_type          text,
    flight_no          text,
    flight_detail      text,
    route_detail       text,
    route_code         text,
    doc_number         text,
    special_type       text,
    route_ref          text,
    booking_class      text,
    trans_code         text,
    tour_code          text,
    agent_code         text,
    payment_method     text,
    issue_date         text,
    revenue_category   text,
    currency           text,
    fare_flag          text,
    base_fare_local    text,
    surcharge          text,
    surcharge_local    text,
    tax                text,
    tax_local          text,
    commission         text,
    commission_local   text,
    total_fare         text,
    total_fare_local   text,
    remark             text,
    origin_station     text,
    total_local_curr   text,
    mileage            text,
    booking_ref        text,
    fare_basis_code    text,
    base_fare_usd      text,
    surcharge_usd      text,
    tax_usd            text,
    commission_usd     text,
    total_fare_usd     text
) ON COMMIT DROP;

\copy tmp_primary_src FROM :'p_primary'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ESCAPE '"', ENCODING 'UTF8');

INSERT INTO xa_rev.stg_revenue_primary (
    carrier_code, service_date, area_type, flight_no, flight_detail,
    route_detail, route_code, doc_number, special_type, route_ref,
    booking_class, trans_code, tour_code, agent_code, payment_method,
    issue_date, revenue_category, currency, fare_flag,
    base_fare_local, surcharge, surcharge_local, tax, tax_local,
    commission, commission_local, total_fare, total_fare_local,
    remark, origin_station, total_local_curr, mileage, booking_ref,
    fare_basis_code, base_fare_usd, surcharge_usd, tax_usd,
    commission_usd, total_fare_usd, period
)
SELECT
    carrier_code, service_date, area_type, flight_no, flight_detail,
    route_detail, route_code, doc_number, special_type, route_ref,
    booking_class, trans_code, tour_code, agent_code, payment_method,
    issue_date, revenue_category, currency, fare_flag,
    base_fare_local, surcharge, surcharge_local, tax, tax_local,
    commission, commission_local, total_fare, total_fare_local,
    remark, origin_station, total_local_curr, mileage, booking_ref,
    fare_basis_code, base_fare_usd, surcharge_usd, tax_usd,
    commission_usd, total_fare_usd,
    DATE '2025-12-01'
FROM tmp_primary_src;

-- =========================
-- TEMP TABLE: ANCILLARY (shared)
-- =========================
CREATE TEMP TABLE tmp_ancillary_src (
    currency           text,
    issue_date         text,
    doc_number         text,
    booking_class      text,
    fare_flag          text,
    fee_local          text,
    service_type       text,
    doc_type_ref       text,
    doc_type           text,
    service_date       text,
    origin             text,
    destination        text,
    flight_no          text,
    trans_code         text,
    doc_category       text,
    base_fare_usd      text,
    fee_usd            text,
    equipment_type     text
) ON COMMIT DROP;

-- DOC TYPE S
\copy tmp_ancillary_src FROM :'p_doc_s'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ESCAPE '"', ENCODING 'UTF8');

INSERT INTO xa_rev.stg_ancillary_doc_s (
    currency, issue_date, doc_number, booking_class, fare_flag,
    fee_local, service_type, doc_type_ref, doc_type, service_date,
    origin, destination, flight_no, trans_code, doc_category,
    base_fare_usd, fee_usd, equipment_type, period
)
SELECT *, DATE '2025-12-01' FROM tmp_ancillary_src;

-- DOC TYPE A
TRUNCATE TABLE tmp_ancillary_src;

\copy tmp_ancillary_src FROM :'p_doc_a'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ESCAPE '"', ENCODING 'UTF8');

INSERT INTO xa_rev.stg_ancillary_doc_a (
    currency, issue_date, doc_number, booking_class, fare_flag,
    fee_local, service_type, doc_type_ref, doc_type, service_date,
    origin, destination, flight_no, trans_code, doc_category,
    base_fare_usd, fee_usd, equipment_type, period
)
SELECT *, DATE '2025-12-01' FROM tmp_ancillary_src;

-- NO-SHOW
TRUNCATE TABLE tmp_ancillary_src;

\copy tmp_ancillary_src FROM :'p_noshow'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ESCAPE '"', ENCODING 'UTF8');

INSERT INTO xa_rev.stg_ancillary_noshow (
    currency, issue_date, doc_number, booking_class, fare_flag,
    fee_local, service_type, doc_type_ref, doc_type, service_date,
    origin, destination, flight_no, trans_code, doc_category,
    base_fare_usd, fee_usd, equipment_type, period
)
SELECT *, DATE '2025-12-01' FROM tmp_ancillary_src;

-- =========================
-- NULL NORMALIZATION
-- =========================
UPDATE xa_rev.stg_ancillary_doc_a
SET base_fare_usd = NULL
WHERE period = DATE '2025-12-01'
  AND UPPER(TRIM(base_fare_usd)) IN ('NULL','N/A','-','#N/A');

UPDATE xa_rev.stg_ancillary_doc_a
SET fee_usd = NULL
WHERE period = DATE '2025-12-01'
  AND UPPER(TRIM(fee_usd)) IN ('NULL','N/A','-','#N/A');

UPDATE xa_rev.stg_ancillary_doc_s
SET base_fare_usd = NULL
WHERE period = DATE '2025-12-01'
  AND UPPER(TRIM(base_fare_usd)) IN ('NULL','N/A','-','#N/A');

UPDATE xa_rev.stg_revenue_primary
SET total_fare_usd = NULL
WHERE period = DATE '2025-12-01'
  AND UPPER(TRIM(total_fare_usd)) IN ('NULL','N/A','-','#N/A');

COMMIT;

-- =========================
-- ROW COUNT VALIDATION
-- =========================
SELECT src, period, COUNT(*) AS row_count
FROM (
    SELECT 'PRIMARY'   AS src, period FROM xa_rev.stg_revenue_primary
    UNION ALL
    SELECT 'DOC_S'     AS src, period FROM xa_rev.stg_ancillary_doc_s
    UNION ALL
    SELECT 'DOC_A'     AS src, period FROM xa_rev.stg_ancillary_doc_a
    UNION ALL
    SELECT 'NOSHOW'    AS src, period FROM xa_rev.stg_ancillary_noshow
) t
GROUP BY src, period
ORDER BY src, period;
