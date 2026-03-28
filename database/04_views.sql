-- ============================================================
-- Global Flight Route Optimization System
-- File: 04_views.sql
-- Description: Views and Materialized Views
-- ============================================================

-- ─────────────────────────────────────────
-- REGULAR VIEW: flight_details
-- Shows full flight info with city names
-- Always fresh — runs underlying query live
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW flight_details AS
SELECT
    f.flight_number,
    f.airline_code,
    al.airline_name,
    orig_city.city_name  AS from_city,
    orig.airport_code    AS from_code,
    orig.airport_name    AS from_airport,
    dest_city.city_name  AS to_city,
    dest.airport_code    AS to_code,
    dest.airport_name    AS to_airport,
    f.departure_time,
    f.arrival_time,
    f.duration_minutes,
    f.distance_km,
    f.days_of_week,
    f.is_active
FROM flights f
JOIN airlines al        ON f.airline_code   = al.airline_code
JOIN airports orig      ON f.origin_airport = orig.airport_code
JOIN airports dest      ON f.dest_airport   = dest.airport_code
JOIN cities orig_city   ON orig.city_id     = orig_city.city_id
JOIN cities dest_city   ON dest.city_id     = dest_city.city_id;

-- Usage:
-- SELECT * FROM flight_details WHERE from_city = 'Mumbai';
-- SELECT * FROM flight_details WHERE airline_code = 'EK';


-- ─────────────────────────────────────────
-- MATERIALIZED VIEW: bom_routes
-- Pre-computed Economy routes from BOM
-- Expensive recursive query stored as snapshot
-- Refresh when flight data changes
-- ─────────────────────────────────────────
CREATE MATERIALIZED VIEW bom_routes AS
WITH RECURSIVE route_finder AS (
    SELECT
        f.flight_id,
        f.origin_airport                    AS start_airport,
        f.dest_airport                      AS current_dest,
        CAST(fp.price_usd AS NUMERIC)       AS total_cost,
        CAST(f.duration_minutes AS INT)     AS total_duration,
        0                                   AS num_stops,
        ARRAY[f.origin_airport::TEXT]       AS visited,
        CAST(f.flight_number AS TEXT)       AS path
    FROM flights f
    JOIN flight_pricing fp ON f.flight_id   = fp.flight_id
    WHERE f.origin_airport = 'BOM'
      AND f.is_active      = TRUE
      AND fp.class_code    = 'E'

    UNION ALL

    SELECT
        f.flight_id,
        rf.start_airport,
        f.dest_airport,
        rf.total_cost + fp.price_usd,
        rf.total_duration + f.duration_minutes + 90,
        rf.num_stops + 1,
        rf.visited || f.origin_airport::TEXT,
        rf.path || ' -> ' || f.flight_number
    FROM flights f
    JOIN flight_pricing fp ON f.flight_id     = fp.flight_id
    JOIN route_finder rf   ON f.origin_airport = rf.current_dest
    WHERE rf.num_stops   < 3
      AND f.is_active    = TRUE
      AND fp.class_code  = 'E'
      AND NOT (f.dest_airport = ANY(rf.visited))
)
SELECT path, current_dest, total_cost, total_duration, num_stops
FROM route_finder;

-- Usage:
-- SELECT * FROM bom_routes WHERE current_dest = 'LHR' ORDER BY total_cost;
-- SELECT * FROM bom_routes WHERE current_dest = 'JFK' ORDER BY total_duration;

-- To refresh after data changes:
-- REFRESH MATERIALIZED VIEW bom_routes;
