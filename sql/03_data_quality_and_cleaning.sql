-- =====================================================================
-- STEP 3: DATA QUALITY CHECKS + BUILD ANALYSIS-READY TABLES
-- Run section by section (select the block, press Ctrl+Enter) the first
-- time so you can SEE each result and note it for your report.
-- =====================================================================
USE olist_db;

-- ---------------------------------------------------------------------
-- PART A. DATA QUALITY CHECKS  (screenshot these for your README)
-- ---------------------------------------------------------------------

-- A1. Date range of the data
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- A2. NULL counts in orders (NULLs are expected for undelivered orders)
SELECT
  SUM(order_approved_at             IS NULL) AS null_approved,
  SUM(order_delivered_carrier_date  IS NULL) AS null_carrier_date,
  SUM(order_delivered_customer_date IS NULL) AS null_delivered_date
FROM orders;

-- A3. Delivered orders that have NO delivery date (data errors -> excluded from delivery analysis)
SELECT COUNT(*) AS delivered_but_no_date
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;

-- A4. Orders that have no items (cannot generate revenue)
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items i ON o.order_id = i.order_id
WHERE i.order_id IS NULL;

-- A5. Orphan check: order_items pointing to missing products/sellers/orders (expect 0)
SELECT
  (SELECT COUNT(*) FROM order_items i LEFT JOIN products p ON i.product_id = p.product_id WHERE p.product_id IS NULL) AS orphan_products,
  (SELECT COUNT(*) FROM order_items i LEFT JOIN sellers  s ON i.seller_id  = s.seller_id  WHERE s.seller_id  IS NULL) AS orphan_sellers,
  (SELECT COUNT(*) FROM order_items i LEFT JOIN orders   o ON i.order_id   = o.order_id   WHERE o.order_id   IS NULL) AS orphan_orders;

-- A6. Products with no category (will be labelled 'unknown')
SELECT COUNT(*) AS products_without_category FROM products WHERE product_category_name IS NULL;

-- A7. Orders with more than one review (we average them per order)
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) t;

-- A8. Orders paid with more than one payment record (we sum them per order)
SELECT COUNT(*) AS orders_with_multiple_payments
FROM (SELECT order_id FROM order_payments GROUP BY order_id HAVING COUNT(*) > 1) t;

-- A9. Illogical dates: delivered BEFORE purchase (expect 0)
SELECT COUNT(*) AS delivered_before_purchase
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- A10. Payment types present
SELECT payment_type, COUNT(*) AS n FROM order_payments GROUP BY payment_type ORDER BY n DESC;

-- ---------------------------------------------------------------------
-- PART B. ORDER_SUMMARY  (one row per order - the main analysis table)
-- Aggregating items / payments / reviews BEFORE joining prevents the
-- classic "fan-out" mistake where revenue is counted several times.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS order_summary;

CREATE TABLE order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    DATE(o.order_purchase_timestamp)                         AS purchase_date,
    YEAR(o.order_purchase_timestamp)                         AS purchase_year,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')         AS purchase_month,
    HOUR(o.order_purchase_timestamp)                         AS purchase_hour,
    WEEKDAY(o.order_purchase_timestamp)                      AS weekday_num,   -- 0 = Monday
    DAYNAME(o.order_purchase_timestamp)                      AS weekday_name,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)       AS delivery_days,
    DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)       AS estimated_days,
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)  AS delay_days,  -- >0 means late
    CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
         WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0 THEN 1
         ELSE 0 END                                          AS is_late,
    i.item_count,
    i.items_revenue,
    i.freight,
    p.payment_value,
    r.avg_review_score
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN (SELECT order_id, COUNT(*) AS item_count, SUM(price) AS items_revenue, SUM(freight_value) AS freight
           FROM order_items GROUP BY order_id) i ON i.order_id = o.order_id
LEFT JOIN (SELECT order_id, SUM(payment_value) AS payment_value
           FROM order_payments GROUP BY order_id) p ON p.order_id = o.order_id
LEFT JOIN (SELECT order_id, AVG(review_score) AS avg_review_score
           FROM order_reviews GROUP BY order_id) r ON r.order_id = o.order_id;

ALTER TABLE order_summary ADD PRIMARY KEY (order_id);
ALTER TABLE order_summary ADD INDEX idx_os_status (order_status);
ALTER TABLE order_summary ADD INDEX idx_os_month  (purchase_month);
ALTER TABLE order_summary ADD INDEX idx_os_cust   (customer_unique_id);
ALTER TABLE order_summary ADD INDEX idx_os_state  (customer_state);

-- ---------------------------------------------------------------------
-- PART C. ITEM_DETAIL  (one row per item sold, with category + seller info)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS item_detail;

CREATE TABLE item_detail AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    COALESCE(t.product_category_name_english, 'unknown')  AS category,
    oi.seller_id,
    s.seller_state,
    s.seller_city,
    oi.price,
    oi.freight_value,
    os.order_status,
    os.purchase_month,
    os.customer_state,
    os.is_late,
    os.delay_days,
    os.avg_review_score
FROM order_items oi
JOIN order_summary os ON os.order_id = oi.order_id
JOIN products p       ON p.product_id = oi.product_id
JOIN sellers s        ON s.seller_id  = oi.seller_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name;

ALTER TABLE item_detail ADD PRIMARY KEY (order_id, order_item_id);
ALTER TABLE item_detail ADD INDEX idx_id_cat    (category);
ALTER TABLE item_detail ADD INDEX idx_id_seller (seller_id);
ALTER TABLE item_detail ADD INDEX idx_id_status (order_status);

-- ---------------------------------------------------------------------
-- PART D. SANITY CHECK  (must match exactly)
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM order_summary) AS order_summary_rows,   -- expect 99441
  (SELECT COUNT(*) FROM item_detail)   AS item_detail_rows,     -- expect 112650
  (SELECT ROUND(SUM(price),2) FROM order_items)  AS revenue_in_raw_items,
  (SELECT ROUND(SUM(price),2) FROM item_detail)  AS revenue_in_item_detail;  -- both must be equal
