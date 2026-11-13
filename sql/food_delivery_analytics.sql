-- ============================================================================
-- HYPERLOCAL FOOD DELIVERY OPERATIONS & SLA ANALYTICS (SQL)
-- Covers: Order Trends, Delivery SLA Breaches, Cancellations & Rating Drivers
-- Compatible with PostgreSQL / MySQL 8.0+ / BigQuery
-- ============================================================================

-- 1. Create Base Table
CREATE TABLE IF NOT EXISTS food_delivery_orders (
    order_id VARCHAR(20) PRIMARY KEY,
    order_timestamp TIMESTAMP NOT NULL,
    order_date DATE NOT NULL,
    order_hour INT,
    is_weekend INT,
    city VARCHAR(50),
    zone VARCHAR(60),
    cuisine VARCHAR(50),
    distance_km DECIMAL(5, 1),
    order_value_inr DECIMAL(10, 2),
    payment_mode VARCHAR(30),
    weather VARCHAR(30),
    traffic_level VARCHAR(30),
    prep_time_mins INT,
    delivery_time_mins INT,
    order_status VARCHAR(20),
    cancellation_reason VARCHAR(80),
    customer_rating DECIMAL(3, 1)
);

-- 2. Executive City-Level KPI Scorecard (Orders, GMV, Delivery SLA, Cancellation %, Rating)
SELECT
    city,
    COUNT(order_id) AS total_orders,
    SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS cancellation_rate_pct,
    ROUND(SUM(CASE WHEN order_status = 'Delivered' THEN order_value_inr ELSE 0 END), 2) AS net_gmv_inr,
    ROUND(AVG(CASE WHEN order_status = 'Delivered' THEN delivery_time_mins END), 1) AS avg_delivery_mins,
    ROUND(SUM(CASE WHEN order_status = 'Delivered' AND delivery_time_mins <= 40 THEN 1 ELSE 0 END) * 100.0 /
          NULLIF(SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END), 0), 1) AS sla_on_time_pct,
    ROUND(AVG(customer_rating), 2) AS avg_customer_rating
FROM food_delivery_orders
GROUP BY city
ORDER BY net_gmv_inr DESC;

-- 3. Meal-Time Demand Peaks & Latency Analysis (Lunch vs. Dinner vs. Off-Peak)
WITH meal_windows AS (
    SELECT
        *,
        CASE
            WHEN order_hour BETWEEN 7 AND 10 THEN '1. Breakfast (07:00-10:59)'
            WHEN order_hour BETWEEN 11 AND 15 THEN '2. Lunch Peak (11:00-15:59)'
            WHEN order_hour BETWEEN 16 AND 18 THEN '3. Evening Snacks (16:00-18:59)'
            WHEN order_hour BETWEEN 19 AND 23 THEN '4. Dinner Peak (19:00-23:59)'
            ELSE '5. Late Night (00:00-06:59)'
        END AS daypart
    FROM food_delivery_orders
)
SELECT
    daypart,
    COUNT(order_id) AS total_orders,
    ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER (), 1) AS order_share_pct,
    ROUND(AVG(prep_time_mins), 1) AS avg_prep_mins,
    ROUND(AVG(delivery_time_mins), 1) AS avg_delivery_mins,
    ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS cancel_rate_pct,
    ROUND(AVG(customer_rating), 2) AS avg_rating
FROM meal_windows
GROUP BY daypart
ORDER BY daypart;

-- 4. Cancellation Root-Cause & Weather/Traffic Stress Matrix
SELECT
    weather,
    traffic_level,
    COUNT(order_id) AS total_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS cancellation_rate_pct,
    ROUND(AVG(delivery_time_mins), 1) AS avg_delivery_mins
FROM food_delivery_orders
GROUP BY weather, traffic_level
ORDER BY cancellation_rate_pct DESC;

-- 5. Delivery SLA Breach Impact on Customer Ratings & Revenue Loss
SELECT
    CASE
        WHEN delivery_time_mins <= 30 THEN 'Fast (<= 30 mins)'
        WHEN delivery_time_mins <= 40 THEN 'On-Time SLA (31-40 mins)'
        WHEN delivery_time_mins <= 50 THEN 'Moderate Delay (41-50 mins)'
        ELSE 'Severe SLA Breach (> 50 mins)'
    END AS sla_tier,
    COUNT(order_id) AS delivered_orders,
    ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER (), 1) AS share_pct,
    ROUND(AVG(customer_rating), 2) AS avg_rating,
    ROUND(SUM(CASE WHEN customer_rating <= 2.5 THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 1) AS poor_rating_pct
FROM food_delivery_orders
WHERE order_status = 'Delivered'
GROUP BY sla_tier
ORDER BY avg_rating DESC;

-- 6. Top 5 High-Cancellation Delivery Zones per City (Window Function Ranking)
WITH zone_stats AS (
    SELECT
        city,
        zone,
        COUNT(order_id) AS total_orders,
        ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS cancel_rate_pct,
        ROUND(AVG(delivery_time_mins), 1) AS avg_delivery_mins,
        RANK() OVER (PARTITION BY city ORDER BY SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 1.0 / COUNT(order_id) DESC) AS cancel_rank
    FROM food_delivery_orders
    GROUP BY city, zone
)
SELECT *
FROM zone_stats
WHERE cancel_rank <= 3
ORDER BY city, cancel_rank;
