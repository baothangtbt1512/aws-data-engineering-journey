-- =========================================================================
-- QUERY 1: WINDOW FUNCTIONS - LEAD & LAG
-- =========================================================================
-- Objective: Calculate the interval (in minutes) between consecutive taxi 
-- pickups originating from JFK Airport (Location ID: 132) on Jan 15, 2023.
-- This helps airport dispatchers understand fleet availability gaps.

WITH airport_trips AS (
    SELECT 
        "PULocationID" AS pickup_location_id,
        "DOLocationID" AS dropoff_location_id,
        tpep_pickup_datetime,
        trip_distance,
        total_amount,
        -- Get the pickup time of the previous trip in this zone
        LAG(tpep_pickup_datetime) OVER (
            PARTITION BY "PULocationID" 
            ORDER BY tpep_pickup_datetime ASC
        ) AS prev_pickup_datetime,
        -- Get the pickup time of the next trip in this zone
        LEAD(tpep_pickup_datetime) OVER (
            PARTITION BY "PULocationID" 
            ORDER BY tpep_pickup_datetime ASC
        ) AS next_pickup_datetime
    FROM yellow_taxi_trips
    WHERE "PULocationID" = 132
      AND tpep_pickup_datetime >= '2023-01-15 00:00:00' 
      AND tpep_pickup_datetime <  '2023-01-16 00:00:00'
)
SELECT 
    pickup_location_id,
    tpep_pickup_datetime,
    prev_pickup_datetime,
    -- Calculate interval in minutes between this trip and previous trip
    ROUND(
        EXTRACT(EPOCH FROM (tpep_pickup_datetime - prev_pickup_datetime)) / 60.0, 
        2
    ) AS minutes_since_last_pickup,
    trip_distance,
    total_amount
FROM airport_trips
ORDER BY tpep_pickup_datetime ASC
LIMIT 50;
