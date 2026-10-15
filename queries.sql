-- 1. REVENUE BY LOCATION  (basic JOIN + aggregation)
-- Which restaurant location generates the most revenue?
SELECT
    r.restaurant_name, r.restaurant_location,
    COUNT(f.transaction_id) AS total_orders,
    ROUND(SUM(f.order_amount_usd), 2) AS total_revenue,
    ROUND(AVG(f.order_amount_usd), 2) AS avg_order_value
FROM fact_transactions f
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_name, r.restaurant_location
ORDER BY total_revenue DESC;


-- 2. MONTHLY REVENUE TREND  (JOIN on dim_date + GROUP BY)
-- How is revenue trending month over month?
SELECT
    d.year, d.month, d.month_name,
    ROUND(SUM(f.order_amount_usd), 2) AS monthly_revenue,
    COUNT(f.transaction_id) AS monthly_orders
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


-- 3. LOYALTY TIER PERFORMANCE  (JOIN + HAVING)
-- Which loyalty tiers redeem the most points relative to what they earn?
SELECT
    c.loyalty_tier,
    COUNT(DISTINCT c.customer_id) AS customers,
    SUM(f.loyalty_points_earned) AS points_earned,
    SUM(f.loyalty_points_redeemed) AS points_redeemed,
    ROUND(
        SUM(f.loyalty_points_redeemed)/ NULLIF(SUM(f.loyalty_points_earned), 0), 3
    ) AS redemption_rate
FROM fact_transactions f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.loyalty_tier
HAVING SUM(f.loyalty_points_earned) > 0
ORDER BY redemption_rate DESC;


-- 4. TOP 5 CUSTOMERS BY SPEND  (window function: RANK)
-- Who are our highest-value customers, and how do they rank?
SELECT customer_id, customer_name, loyalty_tier, total_spend, spend_rank
FROM (
    SELECT
        c.customer_id, c.customer_name, c.loyalty_tier,
        SUM(f.order_amount_usd) AS total_spend,
        RANK() OVER (ORDER BY SUM(f.order_amount_usd) DESC) AS spend_rank
    FROM fact_transactions f
    JOIN dim_customer c ON f.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.loyalty_tier
) ranked
WHERE spend_rank <= 5
ORDER BY spend_rank;


-- 5. DAYS SINCE A CUSTOMER'S PREVIOUS ORDER  (window function: LAG)
-- How much time passes between a customer's visits? (churn risk signal)
SELECT
    f.customer_id, d.visit_date,
    LAG(d.visit_date) OVER (
        PARTITION BY f.customer_id ORDER BY d.visit_date
    ) AS previous_visit_date,
    d.visit_date - LAG(d.visit_date) OVER (
        PARTITION BY f.customer_id ORDER BY d.visit_date
    ) AS days_since_last_visit
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
ORDER BY f.customer_id, d.visit_date;


-- 6. RUNNING TOTAL OF REVENUE BY LOCATION  (window function: SUM OVER)
-- What does the cumulative revenue trend look like per location over time?
SELECT
    r.restaurant_name, d.visit_date, f.order_amount_usd,
    SUM(f.order_amount_usd) OVER (
        PARTITION BY r.restaurant_name ORDER BY d.visit_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM fact_transactions f
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
JOIN dim_date d ON f.date_id = d.date_id
ORDER BY r.restaurant_name, d.visit_date;


-- 7. CUSTOMERS SPENDING ABOVE THEIR TIER'S AVERAGE  (CTE + subquery)
-- Which customers over-index for their loyalty tier (upsell candidates)?
WITH customer_spend AS (
    SELECT
        c.customer_id, c.customer_name, c.loyalty_tier,
        SUM(f.order_amount_usd) AS total_spend
    FROM fact_transactions f
    JOIN dim_customer c ON f.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.loyalty_tier
),
tier_avg AS (
    SELECT loyalty_tier, AVG(total_spend) AS avg_tier_spend
    FROM customer_spend
    GROUP BY loyalty_tier
)
SELECT
    cs.customer_name,
    cs.loyalty_tier,
    cs.total_spend,
    ROUND(ta.avg_tier_spend, 2) AS tier_avg_spend
FROM customer_spend cs
JOIN tier_avg ta ON cs.loyalty_tier = ta.loyalty_tier
WHERE cs.total_spend > ta.avg_tier_spend
ORDER BY cs.loyalty_tier, cs.total_spend DESC;


-- 8. COMPLAINT RATE BY ORDER CHANNEL  (CASE + aggregation)
-- Is one ordering channel (Delivery, Dine-In, etc.) driving more complaints?
SELECT
    order_channel, COUNT(*) AS total_orders,
    SUM(CASE WHEN complaint_flag = 'Yes' THEN 1 ELSE 0 END) AS complaints,
    ROUND(
        100.0 * SUM(CASE WHEN complaint_flag = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2
    ) AS complaint_rate_pct
FROM fact_transactions
GROUP BY order_channel
ORDER BY complaint_rate_pct DESC;


-- 9. HIGHEST-RATED LOCATION PER MONTH  (CTE + window function: ROW_NUMBER)
-- Which location had the best average rating each month?
WITH monthly_ratings AS (
    SELECT
        r.restaurant_name, d.year, d.month,
        AVG(f.customer_rating) AS avg_rating,
        ROW_NUMBER() OVER (
            PARTITION BY d.year, d.month ORDER BY AVG(f.customer_rating) DESC
        ) AS rn
    FROM fact_transactions f
    JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
    JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY r.restaurant_name, d.year, d.month
)
SELECT restaurant_name, year, month, ROUND(avg_rating, 2) AS avg_rating
FROM monthly_ratings
WHERE rn = 1
ORDER BY year, month;


-- 10. WEEKEND VS. WEEKDAY PERFORMANCE  (JOIN + CASE)
-- Do weekends outperform weekdays in revenue and order size?
SELECT
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(f.transaction_id) AS total_orders,
    ROUND(AVG(f.order_amount_usd), 2)  AS avg_order_value,
    ROUND(SUM(f.order_amount_usd), 2)  AS total_revenue
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END;