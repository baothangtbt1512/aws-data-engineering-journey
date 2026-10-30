-- =========================================================================
-- QUERY 2: WINDOW FUNCTIONS - DENSE_RANK() & PARTITION BY
-- =========================================================================
-- Objective: Identify the Top 3 highest-revenue pickup locations 
-- for each calendar day in the first week of January 2023.

WITH daily_location_revenue AS (
    SELECT 
        DATE(tpep_pickup_datetime) AS trip_date,
        "PULocationID" AS pickup_location_id,
        COUNT(*) AS total_trips,
        ROUND(SUM(total_amount)::numeric, 2) AS total_revenue,
        ROUND(AVG(trip_distance)::numeric, 2) AS avg_trip_distance
    FROM yellow_taxi_trips
    WHERE tpep_pickup_datetime >= '2023-01-01 00:00:00' 
      AND tpep_pickup_datetime <  '2023-01-08 00:00:00'
      AND "PULocationID" IS NOT NULL
    GROUP BY 
        DATE(tpep_pickup_datetime), 
        "PULocationID"
),
ranked_daily_locations AS (
    SELECT 
        trip_date,
        pickup_location_id,
        total_trips,
        total_revenue,
        avg_trip_distance,
        -- Rank locations by total revenue within each single day
        DENSE_RANK() OVER (
            PARTITION BY trip_date 
            ORDER BY total_revenue DESC
        ) AS revenue_rank
    FROM daily_location_revenue
)
SELECT 
    trip_date,
    revenue_rank,
    pickup_location_id,
    total_trips,
    total_revenue,
    avg_trip_distance
FROM ranked_daily_locations
WHERE revenue_rank <= 3
ORDER BY 
    trip_date ASC, 
    revenue_rank ASC;
