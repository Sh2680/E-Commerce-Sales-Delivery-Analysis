-- =====================================================================
-- STEP 4: BUSINESS ANALYSIS QUERIES  (20 queries)
-- HOW TO USE:
--   * Run ONE query at a time (click inside it, press Ctrl+Enter).
--   * Under the result grid click "Export" icon -> save as CSV using the
--     file name shown in the "EXCEL SHEET" line above each query.
--   * Revenue = SUM(price) of items in DELIVERED orders (excludes freight).
--   * "Late" = delivered on a date after the estimated delivery date.
-- =====================================================================
USE olist_db;

-- #####################################################################
-- SECTION 1: BUSINESS OVERVIEW
-- #####################################################################

-- Q1 | EXCEL SHEET: 01_KPI_Summary
-- Business question: How big is the business and how healthy is it?
SELECT
    COUNT(*)                                              AS delivered_orders,
    COUNT(DISTINCT customer_unique_id)                    AS unique_customers,
    ROUND(SUM(items_revenue), 2)                          AS total_revenue,
    ROUND(SUM(freight), 2)                                AS total_freight,
    ROUND(AVG(items_revenue), 2)                          AS avg_order_value,
    ROUND(AVG(delivery_days), 1)                          AS avg_delivery_days,
    ROUND(AVG(estimated_days), 1)                         AS avg_estimated_days,
    ROUND(100.0 * SUM(is_late) / COUNT(is_late), 2)       AS late_delivery_pct,
    ROUND(AVG(avg_review_score), 2)                       AS avg_review_score
FROM order_summary
WHERE order_status = 'delivered';

-- Q2 | EXCEL SHEET: 02_Order_Status
-- Business question: How many orders fail to complete?
SELECT
    order_status,
    COUNT(*)                                               AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)     AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Q3 | EXCEL SHEET: 03_Monthly_Trend
-- Business question: How are orders and revenue trending, and what is month-over-month growth?
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)                     AS orders,
           ROUND(SUM(items_revenue), 2) AS revenue,
           ROUND(AVG(items_revenue), 2) AS avg_order_value
    FROM order_summary
    WHERE order_status = 'delivered'
    GROUP BY purchase_month
)
SELECT purchase_month, orders, revenue, avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
                   / LAG(revenue) OVER (ORDER BY purchase_month), 2)   AS revenue_mom_growth_pct,
       ROUND(SUM(revenue) OVER (ORDER BY purchase_month), 2)           AS cumulative_revenue
FROM monthly
ORDER BY purchase_month;

-- Q4 | EXCEL SHEET: 04_Yearly_Summary
-- Business question: How did each year perform?
SELECT purchase_year,
       COUNT(*)                     AS orders,
       ROUND(SUM(items_revenue), 2) AS revenue,
       ROUND(AVG(items_revenue), 2) AS avg_order_value,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM order_summary
WHERE order_status = 'delivered'
GROUP BY purchase_year
ORDER BY purchase_year;

-- Q5 | EXCEL SHEET: 05_Weekday_Pattern
-- Business question: Which day of the week do customers buy most?
SELECT weekday_num, weekday_name,
       COUNT(*)                     AS orders,
       ROUND(SUM(items_revenue), 2) AS revenue
FROM order_summary
WHERE order_status = 'delivered'
GROUP BY weekday_num, weekday_name
ORDER BY weekday_num;

-- Q6 | EXCEL SHEET: 06_Hourly_Pattern
-- Business question: At what hour of the day do customers buy most?
SELECT purchase_hour,
       COUNT(*)                     AS orders,
       ROUND(SUM(items_revenue), 2) AS revenue
FROM order_summary
WHERE order_status = 'delivered'
GROUP BY purchase_hour
ORDER BY purchase_hour;

-- #####################################################################
-- SECTION 2: PRODUCTS & CATEGORIES
-- #####################################################################

-- Q7 | EXCEL SHEET: 07_Category_Performance
-- Business question: Which product categories drive revenue?
SELECT
    RANK() OVER (ORDER BY SUM(price) DESC)                  AS revenue_rank,
    category,
    COUNT(DISTINCT order_id)                                AS orders,
    COUNT(*)                                                AS units_sold,
    ROUND(SUM(price), 2)                                    AS revenue,
    ROUND(100.0 * SUM(price) / SUM(SUM(price)) OVER (), 2)  AS revenue_share_pct,
    ROUND(AVG(price), 2)                                    AS avg_item_price,
    ROUND(AVG(avg_review_score), 2)                         AS avg_review_score
FROM item_detail
WHERE order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC;

-- Q8 | EXCEL SHEET: 08_Pareto_ABC
-- Business question: Do a few categories generate most of the revenue (80/20 rule)?
WITH cat AS (
    SELECT category, SUM(price) AS revenue
    FROM item_detail
    WHERE order_status = 'delivered'
    GROUP BY category
),
ranked AS (
    SELECT category,
           revenue,
           100.0 * revenue / SUM(revenue) OVER ()                                         AS share_pct,
           100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, category) / SUM(revenue) OVER () AS cumulative_pct
    FROM cat
)
SELECT category,
       ROUND(revenue, 2)        AS revenue,
       ROUND(share_pct, 2)      AS share_pct,
       ROUND(cumulative_pct, 2) AS cumulative_pct,
       CASE WHEN cumulative_pct - share_pct < 80 THEN 'A'
            WHEN cumulative_pct - share_pct < 95 THEN 'B'
            ELSE 'C' END        AS abc_class
FROM ranked
ORDER BY revenue DESC;

-- #####################################################################
-- SECTION 3: GEOGRAPHY
-- #####################################################################

-- Q9 | EXCEL SHEET: 09_State_Performance
-- Business question: Which states buy most, and where is delivery the weakest?
SELECT
    customer_state,
    COUNT(*)                                          AS orders,
    COUNT(DISTINCT customer_unique_id)                AS customers,
    ROUND(SUM(items_revenue), 2)                      AS revenue,
    ROUND(AVG(items_revenue), 2)                      AS avg_order_value,
    ROUND(100.0 * SUM(freight) / SUM(items_revenue), 2) AS freight_pct_of_revenue,
    ROUND(AVG(delivery_days), 1)                      AS avg_delivery_days,
    ROUND(100.0 * SUM(is_late) / COUNT(is_late), 2)   AS late_delivery_pct,
    ROUND(AVG(avg_review_score), 2)                   AS avg_review_score
FROM order_summary
WHERE order_status = 'delivered'
GROUP BY customer_state
ORDER BY revenue DESC;

-- #####################################################################
-- SECTION 4: PAYMENTS
-- #####################################################################

-- Q10 | EXCEL SHEET: 10_Payment_Types
-- Business question: How do customers pay?
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id)                                  AS orders,
    ROUND(SUM(p.payment_value), 2)                              AS total_value,
    ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 2) AS value_share_pct,
    ROUND(AVG(p.payment_value), 2)                              AS avg_payment_value
FROM order_payments p
JOIN order_summary os ON os.order_id = p.order_id
WHERE os.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY total_value DESC;

-- Q11 | EXCEL SHEET: 11_Credit_Installments
-- Business question: Do customers split big purchases into installments?
SELECT
    CASE WHEN p.payment_installments <= 1 THEN '1 (pay in full)'
         WHEN p.payment_installments <= 3 THEN '2-3'
         WHEN p.payment_installments <= 6 THEN '4-6'
         WHEN p.payment_installments <= 10 THEN '7-10'
         ELSE '11+' END                      AS installment_group,
    COUNT(*)                                 AS payments,
    ROUND(AVG(p.payment_value), 2)           AS avg_payment_value
FROM order_payments p
JOIN order_summary os ON os.order_id = p.order_id
WHERE os.order_status = 'delivered' AND p.payment_type = 'credit_card'
GROUP BY installment_group
ORDER BY MIN(p.payment_installments);

-- #####################################################################
-- SECTION 5: DELIVERY PERFORMANCE  (the core of this project)
-- #####################################################################

-- Q12 | EXCEL SHEET: 12_Delivery_Trend
-- Business question: Is delivery getting faster or slower over time?
SELECT purchase_month,
       COUNT(delivery_days)                              AS delivered_orders,
       ROUND(AVG(delivery_days), 1)                      AS avg_delivery_days,
       ROUND(AVG(estimated_days), 1)                     AS avg_estimated_days,
       ROUND(100.0 * SUM(is_late) / COUNT(is_late), 2)   AS late_delivery_pct
FROM order_summary
WHERE order_status = 'delivered' AND delivery_days IS NOT NULL
GROUP BY purchase_month
ORDER BY purchase_month;

-- Q13 | EXCEL SHEET: 13_Late_vs_OnTime
-- Business question: Do late deliveries get worse reviews?
SELECT
    CASE WHEN is_late = 1 THEN 'Late' ELSE 'On time / early' END  AS delivery_outcome,
    COUNT(*)                                                      AS orders,
    ROUND(AVG(avg_review_score), 2)                               AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN avg_review_score <= 2 THEN 1 ELSE 0 END)
                / COUNT(avg_review_score), 2)                     AS pct_negative_reviews,
    ROUND(AVG(delivery_days), 1)                                  AS avg_delivery_days
FROM order_summary
WHERE order_status = 'delivered' AND is_late IS NOT NULL
GROUP BY delivery_outcome
ORDER BY delivery_outcome DESC;

-- Q14 | EXCEL SHEET: 14_Delay_Buckets
-- Business question: How quickly does satisfaction fall as delays get longer?
SELECT sort_no, delivery_bucket,
       COUNT(*)                                                   AS orders,
       ROUND(AVG(avg_review_score), 2)                            AS avg_review_score,
       ROUND(100.0 * SUM(CASE WHEN avg_review_score <= 2 THEN 1 ELSE 0 END)
                   / COUNT(avg_review_score), 2)                  AS pct_negative_reviews
FROM (
    SELECT avg_review_score,
           CASE WHEN delay_days <= -8 THEN 1
                WHEN delay_days <= -1 THEN 2
                WHEN delay_days = 0   THEN 3
                WHEN delay_days <= 3  THEN 4
                WHEN delay_days <= 7  THEN 5
                ELSE 6 END AS sort_no,
           CASE WHEN delay_days <= -8 THEN '1. Very early (8+ days before estimate)'
                WHEN delay_days <= -1 THEN '2. Early (1-7 days before estimate)'
                WHEN delay_days = 0   THEN '3. On the estimated date'
                WHEN delay_days <= 3  THEN '4. Late 1-3 days'
                WHEN delay_days <= 7  THEN '5. Late 4-7 days'
                ELSE '6. Late 8+ days' END AS delivery_bucket
    FROM order_summary
    WHERE order_status = 'delivered' AND delay_days IS NOT NULL
) t
GROUP BY sort_no, delivery_bucket
ORDER BY sort_no;

-- #####################################################################
-- SECTION 6: SELLERS
-- #####################################################################

-- Q15 | EXCEL SHEET: 15_Top_Sellers
-- Business question: Who are the top 10 sellers and are they also good quality?
SELECT
    seller_id, seller_state,
    COUNT(DISTINCT order_id)                           AS orders,
    ROUND(SUM(price), 2)                               AS revenue,
    ROUND(AVG(avg_review_score), 2)                    AS avg_review_score,
    ROUND(100.0 * SUM(is_late) / COUNT(is_late), 2)    AS late_item_pct
FROM item_detail
WHERE order_status = 'delivered'
GROUP BY seller_id, seller_state
ORDER BY revenue DESC
LIMIT 10;

-- Q16 | EXCEL SHEET: 16_Risky_Sellers
-- Business question: Which sellers (30+ orders) have the worst customer experience?
SELECT
    seller_id, seller_state,
    COUNT(DISTINCT order_id)                           AS orders,
    ROUND(SUM(price), 2)                               AS revenue,
    ROUND(AVG(avg_review_score), 2)                    AS avg_review_score,
    ROUND(100.0 * SUM(is_late) / COUNT(is_late), 2)    AS late_item_pct
FROM item_detail
WHERE order_status = 'delivered'
GROUP BY seller_id, seller_state
HAVING COUNT(DISTINCT order_id) >= 30
ORDER BY avg_review_score ASC, orders DESC
LIMIT 10;

-- #####################################################################
-- SECTION 7: CUSTOMERS
-- #####################################################################

-- Q17 | EXCEL SHEET: 17_Repeat_Customers
-- Business question: What share of customers buy again?
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM order_summary
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*)                                                      AS total_customers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)                   AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_rate_pct
FROM per_customer;

-- Q18 | EXCEL SHEET: 18_Order_Frequency
-- Business question: How many orders do customers place?
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders, SUM(items_revenue) AS revenue
    FROM order_summary
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT
    CASE WHEN orders >= 4 THEN '4+' ELSE CAST(orders AS CHAR) END AS orders_placed,
    COUNT(*)                                                      AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)            AS pct_of_customers,
    ROUND(SUM(revenue), 2)                                        AS revenue
FROM per_customer
GROUP BY orders_placed
ORDER BY orders_placed;

-- Q19 | EXCEL SHEET: 19_Cohort_Retention
-- Business question: Of customers who first bought in month X, how many came back in later months?
-- (month_index 0 = first purchase month). In Excel: pivot cohort_month x month_index.
WITH cust_orders AS (
    SELECT customer_unique_id, purchase_month,
           CAST(SUBSTR(purchase_month, 1, 4) AS SIGNED) * 12 + CAST(SUBSTR(purchase_month, 6, 2) AS SIGNED) AS month_no
    FROM order_summary
    WHERE order_status = 'delivered'
),
first_purchase AS (
    SELECT customer_unique_id, MIN(month_no) AS first_no, MIN(purchase_month) AS cohort_month
    FROM cust_orders
    GROUP BY customer_unique_id
),
activity AS (
    SELECT f.cohort_month,
           c.month_no - f.first_no             AS month_index,
           COUNT(DISTINCT c.customer_unique_id) AS active_customers
    FROM cust_orders c
    JOIN first_purchase f ON f.customer_unique_id = c.customer_unique_id
    GROUP BY f.cohort_month, c.month_no - f.first_no
)
SELECT cohort_month, month_index, active_customers,
       ROUND(100.0 * active_customers / FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_index), 2) AS retention_pct
FROM activity
ORDER BY cohort_month, month_index;

-- Q20 | EXCEL SHEET: 20_RFM_Segments
-- Business question: Which customer groups should marketing target?
-- R = days since last purchase (lower is better), F = number of orders, M = total spend.
-- R and M are scored 1-5 (5 = best). F is used as a raw count because ~97% of customers buy once.
WITH base AS (
    SELECT customer_unique_id,
           DATEDIFF((SELECT MAX(purchase_date) FROM order_summary WHERE order_status = 'delivered'),
                    MAX(purchase_date))      AS recency_days,
           COUNT(*)                          AS frequency,
           SUM(items_revenue)                AS monetary
    FROM order_summary
    WHERE order_status = 'delivered' AND items_revenue IS NOT NULL
    GROUP BY customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM base
),
segmented AS (
    SELECT *,
           CASE WHEN r_score >= 4 AND m_score >= 4 THEN 'Champions (recent, high spend)'
                WHEN frequency >= 2 AND r_score >= 3 THEN 'Loyal repeat buyers'
                WHEN r_score >= 4                    THEN 'Promising (recent, lower spend)'
                WHEN r_score <= 2 AND m_score >= 4   THEN 'At risk big spenders'
                WHEN r_score <= 2 AND m_score <= 2   THEN 'Lost / low value'
                ELSE 'Needs attention' END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                        AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers,
       ROUND(AVG(recency_days), 0)     AS avg_recency_days,
       ROUND(AVG(frequency), 2)        AS avg_orders,
       ROUND(AVG(monetary), 2)         AS avg_spend,
       ROUND(SUM(monetary), 2)         AS total_revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS pct_of_revenue
FROM segmented
GROUP BY segment
ORDER BY total_revenue DESC;
