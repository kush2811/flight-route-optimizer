-- ============================================================
-- Global Flight Route Optimization System
-- File: 05_queries.sql
-- Description: All advanced queries for the project
-- ============================================================


-- ─────────────────────────────────────────
-- QUERY 1: Direct flight search
-- Find all direct flights between two airports
-- ─────────────────────────────────────────
SELECT
    f.flight_number,
    al.airline_name,
    orig_city.city_name  AS from_city,
    dest_city.city_name  AS to_city,
    f.departure_time,
    f.arrival_time,
    f.duration_minutes,
    fp.price_usd         AS economy_price
FROM flights f
JOIN airlines al        ON f.airline_code   = al.airline_code
JOIN airports orig      ON f.origin_airport = orig.airport_code
JOIN airports dest      ON f.dest_airport   = dest.airport_code
JOIN cities orig_city   ON orig.city_id     = orig_city.city_id
JOIN cities dest_city   ON dest.city_id     = dest_city.city_id
JOIN flight_pricing fp  ON f.flight_id      = fp.flight_id
WHERE f.origin_airport = 'BOM'
  AND f.dest_airport   = 'DXB'
  AND fp.class_code    = 'E'
  AND f.is_active      = TRUE
ORDER BY fp.price_usd ASC;


-- ─────────────────────────────────────────
-- QUERY 2: One-stop route finder
-- Manual join approach (before recursive CTE)
-- ─────────────────────────────────────────
SELECT
    f1.flight_number                        AS first_flight,
    stop_city.city_name                     AS stopover_city,
    f2.flight_number                        AS second_flight,
    f1.base_price_usd + f2.base_price_usd   AS total_price,
    f1.duration_minutes + f2.duration_minutes AS total_duration_mins
FROM flights f1
JOIN flights f2     ON f1.dest_airport  = f2.origin_airport
JOIN airports stop  ON f1.dest_airport  = stop.airport_code
JOIN cities stop_city ON stop.city_id   = stop_city.city_id
WHERE f1.origin_airport = 'BOM'
  AND f2.dest_airport   = 'LHR'
ORDER BY total_price ASC;


-- ─────────────────────────────────────────
-- QUERY 3: Recursive CTE — Multi-hop route optimizer
-- Finds all routes up to 3 stops
-- Supports cost, duration, stops optimization
-- Change ORDER BY to switch optimization mode
-- ─────────────────────────────────────────
WITH RECURSIVE route_finder AS (

    -- BASE CASE: all direct flights from origin
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
    WHERE f.origin_airport = 'BOM'          -- CHANGE: origin airport
      AND f.is_active      = TRUE
      AND fp.class_code    = 'E'            -- CHANGE: E/B/F

    UNION ALL

    -- RECURSIVE CASE: extend path by one hop
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
      AND fp.class_code  = 'E'             -- CHANGE: E/B/F
      AND NOT (f.dest_airport = ANY(rf.visited))
)
SELECT
    path            AS route,
    total_cost      AS price_usd,
    total_duration  AS duration_mins,
    num_stops
FROM route_finder
WHERE current_dest = 'LHR'               -- CHANGE: destination airport
ORDER BY total_cost ASC                  -- CHANGE: total_cost/total_duration/num_stops
LIMIT 5;


-- ─────────────────────────────────────────
-- QUERY 4: Price comparison across all classes
-- Conditional aggregation — pivot rows to columns
-- ─────────────────────────────────────────
SELECT
    f.flight_number,
    f.origin_airport || '->' || f.dest_airport  AS route,
    MAX(CASE WHEN fp.class_code = 'E'
        THEN fp.price_usd END)                  AS economy_price,
    MAX(CASE WHEN fp.class_code = 'B'
        THEN fp.price_usd END)                  AS business_price,
    MAX(CASE WHEN fp.class_code = 'F'
        THEN fp.price_usd END)                  AS first_price
FROM flights f
JOIN flight_pricing fp ON f.flight_id = fp.flight_id
GROUP BY f.flight_number, f.origin_airport, f.dest_airport
ORDER BY f.flight_number;


-- ─────────────────────────────────────────
-- QUERY 5: Window function — competitive ranking
-- Rank airlines by price on same route
-- ─────────────────────────────────────────
SELECT
    f.origin_airport || '->' || f.dest_airport  AS route,
    f.flight_number,
    al.airline_name,
    fp.price_usd,
    RANK() OVER (
        PARTITION BY f.origin_airport, f.dest_airport
        ORDER BY fp.price_usd ASC
    )                                            AS price_rank,
    DENSE_RANK() OVER (
        PARTITION BY f.origin_airport, f.dest_airport
        ORDER BY fp.price_usd ASC
    )                                            AS dense_rank
FROM flights f
JOIN flight_pricing fp  ON f.flight_id    = fp.flight_id
JOIN airlines al        ON f.airline_code = al.airline_code
WHERE fp.class_code = 'E'
ORDER BY route, price_rank;


-- ─────────────────────────────────────────
-- QUERY 6: Busiest routes by flight count
-- ─────────────────────────────────────────
SELECT
    origin_airport || '->' || dest_airport  AS route,
    COUNT(*)                                AS num_flights,
    AVG(duration_minutes)                   AS avg_duration_mins,
    MIN(base_price_usd)                     AS min_price,
    MAX(base_price_usd)                     AS max_price
FROM flights
WHERE is_active = TRUE
GROUP BY origin_airport, dest_airport
ORDER BY num_flights DESC;


-- ─────────────────────────────────────────
-- QUERY 7: Airports with no outbound flights
-- Data integrity check
-- ─────────────────────────────────────────
SELECT a.airport_code, a.airport_name
FROM airports a
LEFT JOIN flights f ON a.airport_code = f.origin_airport
                   AND f.is_active = TRUE
WHERE f.flight_id IS NULL
  AND a.is_active = TRUE;


-- ─────────────────────────────────────────
-- QUERY 8: All flights from Indian airports
-- Multi-table JOIN across 5 tables
-- ─────────────────────────────────────────
SELECT
    f.flight_number,
    al.airline_name,
    orig_city.city_name  AS from_city,
    dest_city.city_name  AS to_city,
    f.duration_minutes,
    fp.price_usd         AS economy_price
FROM flights f
JOIN airlines al        ON f.airline_code     = al.airline_code
JOIN airports orig      ON f.origin_airport   = orig.airport_code
JOIN airports dest      ON f.dest_airport     = dest.airport_code
JOIN cities orig_city   ON orig.city_id       = orig_city.city_id
JOIN cities dest_city   ON dest.city_id       = dest_city.city_id
JOIN countries co       ON orig_city.country_code = co.country_code
JOIN flight_pricing fp  ON f.flight_id        = fp.flight_id
WHERE co.country_name   = 'India'
  AND fp.class_code     = 'E'
ORDER BY fp.price_usd ASC;
