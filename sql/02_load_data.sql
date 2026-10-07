-- =====================================================================
-- STEP 2: LOAD THE CSV FILES INTO MYSQL
-- ---------------------------------------------------------------------
-- BEFORE RUNNING - do these 3 things:
--
--  (1) Make a folder with NO spaces in the path, e.g.  C:/olist_data/
--      Copy ALL of these files into it:
--        olist_customers_dataset.csv
--        olist_sellers_dataset.csv
--        olist_products_dataset.csv
--        olist_orders_dataset.csv
--        olist_order_items_dataset.csv
--        olist_order_payments_dataset.csv
--        olist_order_reviews_clean.csv                (from data_clean folder)
--        product_category_name_translation_clean.csv  (from data_clean folder)
--
--  (2) If your folder is not C:/olist_data/, use Find & Replace in
--      Workbench to change every  C:/olist_data/  to your folder.
--      ALWAYS use forward slashes (/) even on Windows.
--
--  (3) LOCAL INFILE must be ON. Run this once as an admin user:
--          SET GLOBAL local_infile = 1;
--      And in Workbench: Database -> Manage Connections -> select your
--      connection -> Advanced tab -> in "Others" box type:
--          OPT_LOCAL_INFILE=1
--      Then close and re-open the connection.
--
-- (the geolocation CSV is NOT loaded: 1M rows, not needed for this project)
-- =====================================================================

USE olist_db;
SET SESSION sql_mode = '';   -- lenient mode for loading only; resets when you disconnect

-- ---------- customers ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

-- ---------- sellers ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

-- ---------- category translation ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/product_category_name_translation_clean.csv'
INTO TABLE category_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_category_name, product_category_name_english);

-- ---------- products (empty cells -> NULL) ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @cat, @name_len, @desc_len, @photos, @weight, @len, @height, @width)
SET product_category_name      = NULLIF(@cat, ''),
    product_name_length        = NULLIF(@name_len, ''),
    product_description_length = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@len, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

-- ---------- orders (empty dates -> NULL) ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, order_purchase_timestamp,
 @approved, @carrier, @delivered, @estimated)
SET order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(@estimated, '');

-- ---------- order_items ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value);

-- ---------- order_payments ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

-- ---------- order_reviews (cleaned file) ----------
LOAD DATA LOCAL INFILE 'C:/olist_data/olist_order_reviews_clean.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id, order_id, review_score, review_creation_date, review_answer_timestamp);

-- ---------- two categories exist in products but not in the translation file ----------
INSERT IGNORE INTO category_translation VALUES
  ('pc_gamer', 'pc_gamer'),
  ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers');

-- =====================================================================
-- VERIFY: every row below must say OK.  If not, a load failed.
-- =====================================================================
SELECT 'customers'            AS table_name, COUNT(*) AS rows_loaded, 99441  AS expected, IF(COUNT(*)=99441 ,'OK','CHECK') AS result FROM customers
UNION ALL SELECT 'sellers',              COUNT(*), 3095,   IF(COUNT(*)=3095  ,'OK','CHECK') FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*), 73,     IF(COUNT(*)=73    ,'OK','CHECK') FROM category_translation
UNION ALL SELECT 'products',             COUNT(*), 32951,  IF(COUNT(*)=32951 ,'OK','CHECK') FROM products
UNION ALL SELECT 'orders',               COUNT(*), 99441,  IF(COUNT(*)=99441 ,'OK','CHECK') FROM orders
UNION ALL SELECT 'order_items',          COUNT(*), 112650, IF(COUNT(*)=112650,'OK','CHECK') FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*), 103886, IF(COUNT(*)=103886,'OK','CHECK') FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*), 99224,  IF(COUNT(*)=99224 ,'OK','CHECK') FROM order_reviews;
