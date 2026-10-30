-- =========================================================================
-- QUERY 3: ADVANCED AGGREGATES & CONDITIONAL ANALYSIS
-- =========================================================================
-- Objective: Multi-dimensional breakdown by Time of Day (Rush Hour vs Normal)
-- and Payment Type (Credit Card vs Cash) to analyze Tip Habits and Revenue.

WITH cleaned_trips AS (
    SELECT 
        tpep_pickup_datetime,
        EXTRACT(HOUR FROM tpep_pickup_datetime) AS pickup_hour,
        trip_distance,
        fare_amount,
        tip_amount,
        total_amount,
        payment_type,
        CASE 
            WHEN payment_type = 1 THEN 'Credit Card'
            WHEN payment_type = 2 THEN 'Cash'
            WHEN payment_type = 3 THEN 'No Charge'
            WHEN payment_type = 4 THEN 'Dispute'
            ELSE 'Unknown/Other'
        END AS payment_method_name,
        CASE 
            WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) IN (7, 8, 9, 16, 17, 18, 19) THEN 'Rush Hour'
            WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 0 AND 5 THEN 'Late Night'
            ELSE 'Regular Daytime'
        END AS day_time_category
    FROM yellow_taxi_trips
    WHERE fare_amount > 0 
      AND trip_distance > 0
      AND tpep_pickup_datetime >= '2023-01-01 00:00:00'
      AND tpep_pickup_datetime <  '2023-02-01 00:00:00'
)
SELECT 
    day_time_category,
    payment_method_name,
    COUNT(*) AS total_rides,
    ROUND(AVG(trip_distance)::numeric, 2) AS avg_distance_miles,
    ROUND(AVG(fare_amount)::numeric, 2) AS avg_fare,
    ROUND(AVG(tip_amount)::numeric, 2) AS avg_tip,
    -- Tip Percentage over Fare Amount (only relevant for Card transactions)
    ROUND(
        (SUM(tip_amount) / NULLIF(SUM(fare_amount), 0) * 100)::numeric, 
        2
    ) AS tip_percentage_rate,
    ROUND(SUM(total_amount)::numeric, 2) AS gross_revenue
FROM cleaned_trips
GROUP BY 
    day_time_category, 
    payment_method_name
ORDER BY 
    day_time_category, 
    gross_revenue DESC;
