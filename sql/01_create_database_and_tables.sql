-- =====================================================================
-- OLIST E-COMMERCE ANALYTICS PROJECT  |  STEP 1: CREATE DATABASE & TABLES
-- Database : MySQL 8.0+
-- How to run: open this file in MySQL Workbench -> click the lightning
--             bolt icon (Execute All). Run it ONCE.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS olist_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE olist_db;

-- Drop in reverse order so the script can be re-run safely
DROP TABLE IF EXISTS item_detail;
DROP TABLE IF EXISTS order_summary;
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS category_translation;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;

-- ---------------------------------------------------------------------
-- 1. customers  (99,441 rows)
-- NOTE: customer_id is unique PER ORDER. The same real person can have
--       several customer_id values. customer_unique_id identifies the
--       real person -> use it for repeat-customer analysis.
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id               CHAR(32)    NOT NULL,
    customer_unique_id        CHAR(32)    NOT NULL,
    customer_zip_code_prefix  CHAR(5),            -- CHAR keeps leading zeros (e.g. 09790)
    customer_city             VARCHAR(60),
    customer_state            CHAR(2),
    PRIMARY KEY (customer_id),
    INDEX idx_cust_unique (customer_unique_id),
    INDEX idx_cust_state  (customer_state)
);

-- ---------------------------------------------------------------------
-- 2. sellers  (3,095 rows)
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id               CHAR(32) NOT NULL,
    seller_zip_code_prefix  CHAR(5),
    seller_city             VARCHAR(60),
    seller_state            CHAR(2),
    PRIMARY KEY (seller_id)
);

-- ---------------------------------------------------------------------
-- 3. category_translation  (71 rows + 2 missing ones added later)
-- ---------------------------------------------------------------------
CREATE TABLE category_translation (
    product_category_name          VARCHAR(60) NOT NULL,
    product_category_name_english  VARCHAR(60),
    PRIMARY KEY (product_category_name)
);

-- ---------------------------------------------------------------------
-- 4. products  (32,951 rows)
-- (the original CSV spells "length" as "lenght"; we use correct spelling)
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id                  CHAR(32) NOT NULL,
    product_category_name       VARCHAR(60),
    product_name_length         INT,
    product_description_length  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT,
    PRIMARY KEY (product_id),
    INDEX idx_prod_cat (product_category_name)
);

-- ---------------------------------------------------------------------
-- 5. orders  (99,441 rows)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id                       CHAR(32)    NOT NULL,
    customer_id                    CHAR(32)    NOT NULL,
    order_status                   VARCHAR(20) NOT NULL,
    order_purchase_timestamp       DATETIME    NOT NULL,
    order_approved_at              DATETIME,
    order_delivered_carrier_date   DATETIME,
    order_delivered_customer_date  DATETIME,
    order_estimated_delivery_date  DATETIME,
    PRIMARY KEY (order_id),
    INDEX idx_ord_cust   (customer_id),
    INDEX idx_ord_status (order_status),
    INDEX idx_ord_date   (order_purchase_timestamp)
);

-- ---------------------------------------------------------------------
-- 6. order_items  (112,650 rows)  one row per product in an order
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id             CHAR(32)      NOT NULL,
    order_item_id        INT           NOT NULL,
    product_id           CHAR(32)      NOT NULL,
    seller_id            CHAR(32)      NOT NULL,
    shipping_limit_date  DATETIME,
    price                DECIMAL(10,2) NOT NULL,
    freight_value        DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_item_prod   (product_id),
    INDEX idx_item_seller (seller_id)
);

-- ---------------------------------------------------------------------
-- 7. order_payments  (103,886 rows)  an order can use several payments
-- ---------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id              CHAR(32)      NOT NULL,
    payment_sequential    INT           NOT NULL,
    payment_type          VARCHAR(20),
    payment_installments  INT,
    payment_value         DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- ---------------------------------------------------------------------
-- 8. order_reviews  (99,224 rows)
-- Free-text comments were removed in the cleaned CSV (Portuguese text,
-- not needed, and its embedded line-breaks break CSV loading).
-- NOTE: review_id is NOT unique (814 repeats), but (review_id, order_id) is.
-- ---------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id                CHAR(32) NOT NULL,
    order_id                 CHAR(32) NOT NULL,
    review_score             TINYINT,
    review_creation_date     DATETIME,
    review_answer_timestamp  DATETIME,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_rev_order (order_id)
);

SELECT 'Tables created successfully' AS status;
SHOW TABLES;
