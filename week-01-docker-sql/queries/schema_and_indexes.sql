-- =========================================================================
-- INDEXING STRATEGY & QUERY OPTIMIZATION
-- =========================================================================
-- In OLTP databases like PostgreSQL (or AWS RDS / Aurora PostgreSQL),
-- indexes are critical for avoiding Full Table Scans on multi-million row tables.

-- 1. Check table row count
SELECT COUNT(*) AS total_trips FROM yellow_taxi_trips;

-- 2. Performance before Indexing (Observe Execution Time)
EXPLAIN ANALYZE
SELECT 
    tpep_pickup_datetime, 
    "PULocationID", 
    trip_distance, 
    total_amount 
FROM yellow_taxi_trips 
WHERE tpep_pickup_datetime BETWEEN '2023-01-15 00:00:00' AND '2023-01-15 23:59:59'
  AND "PULocationID" = 132;

-- 3. Create B-Tree Indexes on commonly filtered & joined columns
-- Index on Pickup Datetime (for time-range filtering)
CREATE INDEX IF NOT EXISTS idx_yellow_taxi_pickup_datetime 
ON yellow_taxi_trips (tpep_pickup_datetime);

-- Composite Index on Pickup Location & Pickup Datetime
CREATE INDEX IF NOT EXISTS idx_yellow_taxi_pu_loc_datetime 
ON yellow_taxi_trips ("PULocationID", tpep_pickup_datetime);

-- 4. Performance after Indexing
-- Notice the scan changes from "Seq Scan" (Sequential Scan) to "Index Scan / Bitmap Index Scan"
EXPLAIN ANALYZE
SELECT 
    tpep_pickup_datetime, 
    "PULocationID", 
    trip_distance, 
    total_amount 
FROM yellow_taxi_trips 
WHERE tpep_pickup_datetime BETWEEN '2023-01-15 00:00:00' AND '2023-01-15 23:59:59'
  AND "PULocationID" = 132;
