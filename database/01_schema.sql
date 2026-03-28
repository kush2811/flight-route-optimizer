-- ============================================================
-- Global Flight Route Optimization System
-- File: 01_schema.sql
-- Description: Complete database schema (run this first)
-- ============================================================

-- Drop tables in reverse order (to respect foreign keys)
DROP TABLE IF EXISTS flight_pricing CASCADE;
DROP TABLE IF EXISTS flights CASCADE;
DROP TABLE IF EXISTS airlines CASCADE;
DROP TABLE IF EXISTS airports CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

-- ─────────────────────────────────────────
-- TABLE 1: countries
-- Foundation of the geographic hierarchy
-- ─────────────────────────────────────────
CREATE TABLE countries (
    country_code   CHAR(2)      PRIMARY KEY,
    country_name   VARCHAR(100) NOT NULL,
    continent      VARCHAR(50)  NOT NULL,

    CONSTRAINT chk_continent CHECK (
        continent IN (
            'Asia', 'Europe', 'Americas',
            'Africa', 'Oceania', 'Antarctica'
        )
    )
);

-- ─────────────────────────────────────────
-- TABLE 2: cities
-- Cities belong to countries
-- ─────────────────────────────────────────
CREATE TABLE cities (
    city_id      SERIAL        PRIMARY KEY,
    city_name    VARCHAR(100)  NOT NULL,
    country_code CHAR(2)       NOT NULL,
    latitude     DECIMAL(9,6)  NOT NULL,
    longitude    DECIMAL(9,6)  NOT NULL,
    timezone     VARCHAR(50)   NOT NULL,

    CONSTRAINT fk_city_country
        FOREIGN KEY (country_code)
        REFERENCES countries(country_code),

    CONSTRAINT uq_city_country
        UNIQUE(city_name, country_code)
);

-- ─────────────────────────────────────────
-- TABLE 3: airports
-- Airports belong to cities
-- IATA code is the natural primary key
-- ─────────────────────────────────────────
CREATE TABLE airports (
    airport_code     CHAR(3)       PRIMARY KEY,
    airport_name     VARCHAR(150)  NOT NULL,
    city_id          INT           NOT NULL,
    latitude         DECIMAL(9,6)  NOT NULL,
    longitude        DECIMAL(9,6)  NOT NULL,
    elevation_ft     INT           DEFAULT 0,
    num_terminals    SMALLINT      NOT NULL DEFAULT 1,
    num_gates        SMALLINT,
    is_international BOOLEAN       NOT NULL DEFAULT TRUE,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_airport_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id),

    CONSTRAINT chk_airport_code
        CHECK (airport_code ~ '^[A-Z]{3}$')
);

-- ─────────────────────────────────────────
-- TABLE 4: airlines
-- Airlines belong to countries, hub at an airport
-- ─────────────────────────────────────────
CREATE TABLE airlines (
    airline_code    CHAR(2)      PRIMARY KEY,
    airline_name    VARCHAR(100) NOT NULL UNIQUE,
    country_code    CHAR(2)      NOT NULL,
    hub_airport     CHAR(3),
    founded_year    SMALLINT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_airline_country
        FOREIGN KEY (country_code)
        REFERENCES countries(country_code),

    CONSTRAINT fk_airline_hub
        FOREIGN KEY (hub_airport)
        REFERENCES airports(airport_code),

    CONSTRAINT chk_airline_code
        CHECK (airline_code ~ '^[A-Z0-9]{2}$'),

    CONSTRAINT chk_founded_year
        CHECK (founded_year BETWEEN 1900 AND 2100)
);

-- ─────────────────────────────────────────
-- TABLE 5: flights
-- The core edge table — connects airports
-- Every route query runs on this table
-- ─────────────────────────────────────────
CREATE TABLE flights (
    flight_id        SERIAL        PRIMARY KEY,
    flight_number    VARCHAR(10)   NOT NULL,
    airline_code     CHAR(2)       NOT NULL,
    origin_airport   CHAR(3)       NOT NULL,
    dest_airport     CHAR(3)       NOT NULL,
    departure_time   TIME          NOT NULL,
    arrival_time     TIME          NOT NULL,
    duration_minutes INT           NOT NULL,
    distance_km      INT           NOT NULL,
    base_price_usd   DECIMAL(10,2) NOT NULL,
    days_of_week     VARCHAR(7)    NOT NULL DEFAULT '1111111',
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_flight_airline
        FOREIGN KEY (airline_code)
        REFERENCES airlines(airline_code),

    CONSTRAINT fk_flight_origin
        FOREIGN KEY (origin_airport)
        REFERENCES airports(airport_code),

    CONSTRAINT fk_flight_dest
        FOREIGN KEY (dest_airport)
        REFERENCES airports(airport_code),

    CONSTRAINT chk_different_airports
        CHECK (origin_airport <> dest_airport),

    CONSTRAINT chk_positive_duration
        CHECK (duration_minutes > 0),

    CONSTRAINT chk_positive_distance
        CHECK (distance_km > 0),

    CONSTRAINT chk_positive_price
        CHECK (base_price_usd > 0),

    CONSTRAINT chk_days_format
        CHECK (days_of_week ~ '^[01]{7}$'),

    UNIQUE(flight_number, departure_time)
);

-- ─────────────────────────────────────────
-- TABLE 6: flight_pricing
-- Normalized pricing — one row per flight per class
-- Separating pricing from flights is 3NF design
-- ─────────────────────────────────────────
CREATE TABLE flight_pricing (
    pricing_id      SERIAL          PRIMARY KEY,
    flight_id       INT             NOT NULL,
    class_code      CHAR(1)         NOT NULL,
    class_name      VARCHAR(20)     NOT NULL,
    price_usd       DECIMAL(10,2)   NOT NULL,
    available_seats SMALLINT        NOT NULL DEFAULT 0,

    CONSTRAINT fk_pricing_flight
        FOREIGN KEY (flight_id)
        REFERENCES flights(flight_id),

    CONSTRAINT chk_class_code
        CHECK (class_code IN ('E', 'B', 'F', 'P')),

    CONSTRAINT chk_price_positive
        CHECK (price_usd > 0),

    CONSTRAINT chk_seats_positive
        CHECK (available_seats >= 0),

    CONSTRAINT uq_flight_class
        UNIQUE (flight_id, class_code)
);
