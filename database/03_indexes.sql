-- ============================================================
-- Global Flight Route Optimization System
-- File: 03_indexes.sql
-- Description: Performance indexes (run after 02_seed_data.sql)
-- ============================================================

-- Most critical: recursive CTE joins on origin every iteration
CREATE INDEX idx_flights_origin
ON flights(origin_airport)
WHERE is_active = TRUE;

-- Destination lookups
CREATE INDEX idx_flights_dest
ON flights(dest_airport)
WHERE is_active = TRUE;

-- Composite: covers queries filtering BOTH origin AND destination
-- Enables index-only scans for direct route lookups
CREATE INDEX idx_flights_route
ON flights(origin_airport, dest_airport)
WHERE is_active = TRUE;

-- Pricing lookups: always joined with class filter
CREATE INDEX idx_pricing_flight_class
ON flight_pricing(flight_id, class_code);

-- Airline filter queries
CREATE INDEX idx_flights_airline
ON flights(airline_code)
WHERE is_active = TRUE;
