-- ============================================================
-- Global Flight Route Optimization System
-- File: 02_seed_data.sql
-- Description: All sample data (run after 01_schema.sql)
-- ============================================================

-- ─────────────────────────────────────────
-- COUNTRIES (8 rows)
-- ─────────────────────────────────────────
INSERT INTO countries (country_code, country_name, continent)
VALUES
    ('IN', 'India',          'Asia'),
    ('US', 'United States',  'Americas'),
    ('GB', 'United Kingdom', 'Europe'),
    ('AE', 'UAE',            'Asia'),
    ('SG', 'Singapore',      'Asia'),
    ('DE', 'Germany',        'Europe'),
    ('AU', 'Australia',      'Oceania'),
    ('JP', 'Japan',          'Asia');

-- ─────────────────────────────────────────
-- CITIES (10 rows)
-- ─────────────────────────────────────────
INSERT INTO cities (city_name, country_code, latitude, longitude, timezone)
VALUES
    ('Mumbai',    'IN',  19.076090,   72.877426, 'Asia/Kolkata'),
    ('Delhi',     'IN',  28.613939,   77.209023, 'Asia/Kolkata'),
    ('New York',  'US',  40.712776,  -74.005974, 'America/New_York'),
    ('London',    'GB',  51.507351,   -0.127758, 'Europe/London'),
    ('Dubai',     'AE',  25.204849,   55.270782, 'Asia/Dubai'),
    ('Singapore', 'SG',   1.352083,  103.819836, 'Asia/Singapore'),
    ('Frankfurt', 'DE',  50.110922,    8.682127, 'Europe/Berlin'),
    ('Sydney',    'AU', -33.868820,  151.209296, 'Australia/Sydney'),
    ('Tokyo',     'JP',  35.689487,  139.691711, 'Asia/Tokyo'),
    ('Bengaluru', 'IN',  12.971599,   77.594566, 'Asia/Kolkata');

-- ─────────────────────────────────────────
-- AIRPORTS (10 rows)
-- city_id matches insertion order above:
-- 1=Mumbai, 2=Delhi, 3=New York, 4=London
-- 5=Dubai, 6=Singapore, 7=Frankfurt
-- 8=Sydney, 9=Tokyo, 10=Bengaluru
-- ─────────────────────────────────────────
INSERT INTO airports (
    airport_code, airport_name, city_id,
    latitude, longitude, elevation_ft,
    num_terminals, num_gates, is_international
)
VALUES
    ('BOM', 'Chhatrapati Shivaji Maharaj Intl', 1,  19.088700,  72.867919,   37, 2,  72, TRUE),
    ('DEL', 'Indira Gandhi International',      2,  28.556160,  77.100140,  777, 3,  78, TRUE),
    ('JFK', 'John F Kennedy International',     3,  40.639722, -73.778889,   13, 6, 128, TRUE),
    ('LHR', 'London Heathrow',                  4,  51.477500,  -0.461389,   83, 5, 115, TRUE),
    ('DXB', 'Dubai International',              5,  25.252778,  55.364444,   62, 3,  98, TRUE),
    ('SIN', 'Singapore Changi',                 6,   1.359167, 103.989444,   22, 4, 130, TRUE),
    ('FRA', 'Frankfurt am Main',                7,  50.026421,   8.543125,  364, 2,  75, TRUE),
    ('SYD', 'Sydney Kingsford Smith',           8, -33.946111, 151.177222,   21, 3,  59, TRUE),
    ('HND', 'Tokyo Haneda',                     9,  35.552258, 139.779694,   35, 4, 113, TRUE),
    ('BLR', 'Kempegowda International',        10,  13.198889,  77.705556, 3000, 2,  50, TRUE);

-- ─────────────────────────────────────────
-- AIRLINES (10 rows)
-- ─────────────────────────────────────────
INSERT INTO airlines
    (airline_code, airline_name, country_code, hub_airport, founded_year)
VALUES
    ('AI', 'Air India',           'IN', 'DEL', 1932),
    ('6E', 'IndiGo',              'IN', 'DEL', 2006),
    ('EK', 'Emirates',            'AE', 'DXB', 1985),
    ('SQ', 'Singapore Airlines',  'SG', 'SIN', 1947),
    ('LH', 'Lufthansa',           'DE', 'FRA', 1953),
    ('BA', 'British Airways',     'GB', 'LHR', 1974),
    ('QF', 'Qantas',              'AU', 'SYD', 1920),
    ('NH', 'All Nippon Airways',  'JP', 'HND', 1952),
    ('UA', 'United Airlines',     'US', 'JFK', 1926),
    ('IX', 'Air India Express',   'IN', 'BOM', 2005);

-- ─────────────────────────────────────────
-- FLIGHTS (19 rows)
-- ─────────────────────────────────────────
INSERT INTO flights (
    flight_number, airline_code, origin_airport, dest_airport,
    departure_time, arrival_time, duration_minutes,
    distance_km, base_price_usd, days_of_week
)
VALUES
    -- India domestic
    ('AI-101',  'AI', 'BOM', 'DEL', '06:00', '08:10', 130,  1148,  85.00, '1111111'),
    ('6E-204',  '6E', 'DEL', 'BOM', '09:00', '11:15', 135,  1148,  72.00, '1111111'),
    ('AI-102',  'AI', 'DEL', 'BLR', '07:00', '09:30', 150,  1740,  95.00, '1111100'),
    ('6E-301',  '6E', 'BOM', 'BLR', '08:00', '09:45', 105,   984,  55.00, '1111111'),

    -- India to Middle East
    ('EK-500',  'EK', 'BOM', 'DXB', '14:00', '16:30', 150,  1930, 180.00, '1111111'),
    ('AI-960',  'AI', 'DEL', 'DXB', '03:00', '05:15', 135,  2194, 165.00, '1111111'),

    -- Middle East to Europe/US
    ('EK-201',  'EK', 'DXB', 'LHR', '08:00', '13:00', 420,  5490, 520.00, '1111111'),
    ('EK-203',  'EK', 'DXB', 'JFK', '09:00', '15:30', 810, 11020, 850.00, '1111111'),

    -- India to Singapore
    ('SQ-401',  'SQ', 'BOM', 'SIN', '10:00', '20:00', 360,  4356, 310.00, '1111111'),
    ('SQ-403',  'SQ', 'DEL', 'SIN', '11:00', '21:00', 360,  4150, 290.00, '1111111'),

    -- Singapore to rest of world
    ('SQ-317',  'SQ', 'SIN', 'LHR', '23:00', '05:30', 750, 10840, 680.00, '1111111'),
    ('SQ-025',  'SQ', 'SIN', 'JFK', '00:05', '06:05',1080, 15332, 920.00, '1111100'),

    -- Europe routes
    ('LH-757',  'LH', 'FRA', 'JFK', '10:30', '13:00', 510,  6200, 580.00, '1111111'),
    ('BA-117',  'BA', 'LHR', 'JFK', '11:00', '14:00', 420,  5570, 560.00, '1111111'),

    -- To Australia
    ('QF-001',  'QF', 'LHR', 'SYD', '21:00', '05:00',1415, 16993, 980.00, '0101010'),
    ('SQ-221',  'SQ', 'SIN', 'SYD', '08:00', '17:30', 510,  6307, 420.00, '1111111'),

    -- Competing flights on BOM→DXB (for window function demo)
    ('AI-971',  'AI', 'BOM', 'DXB', '21:00', '23:15', 135,  1930, 170.00, '1111111'),
    ('IX-191',  'IX', 'BOM', 'DXB', '18:00', '20:20', 140,  1930, 145.00, '1111100'),

    -- Competing flight on DEL→BOM
    ('AI-131',  'AI', 'DEL', 'BOM', '14:00', '16:10', 130,  1148,  68.00, '1111111');

-- ─────────────────────────────────────────
-- FLIGHT PRICING
-- Multiple classes per flight
-- flight_id matches insertion order above
-- ─────────────────────────────────────────
INSERT INTO flight_pricing (flight_id, class_code, class_name, price_usd, available_seats)
VALUES
    -- flight 1: AI-101 (BOM→DEL)
    (1,  'E', 'Economy',   85.00, 150),
    (1,  'B', 'Business', 220.00,  20),
    (1,  'F', 'First',    450.00,   8),

    -- flight 2: 6E-204 (DEL→BOM)
    (2,  'E', 'Economy',   72.00, 160),
    (2,  'B', 'Business', 190.00,  16),

    -- flight 3: AI-102 (DEL→BLR)
    (3,  'E', 'Economy',   95.00, 140),
    (3,  'B', 'Business', 260.00,  18),

    -- flight 4: 6E-301 (BOM→BLR)
    (4,  'E', 'Economy',   55.00, 165),
    (4,  'B', 'Business', 150.00,  14),

    -- flight 5: EK-500 (BOM→DXB)
    (5,  'E', 'Economy',  180.00, 200),
    (5,  'B', 'Business', 520.00,  42),
    (5,  'F', 'First',   1200.00,  14),

    -- flight 6: AI-960 (DEL→DXB)
    (6,  'E', 'Economy',  165.00, 180),
    (6,  'B', 'Business', 480.00,  36),

    -- flight 7: EK-201 (DXB→LHR)
    (7,  'E', 'Economy',  520.00, 210),
    (7,  'B', 'Business',1400.00,  48),
    (7,  'F', 'First',   3200.00,  16),

    -- flight 8: EK-203 (DXB→JFK)
    (8,  'E', 'Economy',  850.00, 210),
    (8,  'B', 'Business',2200.00,  48),
    (8,  'F', 'First',   4500.00,  14),

    -- flight 9: SQ-401 (BOM→SIN)
    (9,  'E', 'Economy',  310.00, 180),
    (9,  'B', 'Business', 850.00,  42),
    (9,  'F', 'First',   1800.00,  12),

    -- flight 10: SQ-403 (DEL→SIN)
    (10, 'E', 'Economy',  290.00, 180),
    (10, 'B', 'Business', 780.00,  42),

    -- flight 11: SQ-317 (SIN→LHR)
    (11, 'E', 'Economy',  680.00, 200),
    (11, 'B', 'Business',1800.00,  48),
    (11, 'F', 'First',   3800.00,  14),

    -- flight 12: SQ-025 (SIN→JFK)
    (12, 'E', 'Economy',  920.00, 188),
    (12, 'B', 'Business',2400.00,  42),
    (12, 'F', 'First',   5200.00,  12),

    -- flight 13: LH-757 (FRA→JFK)
    (13, 'E', 'Economy',  580.00, 180),
    (13, 'B', 'Business',1600.00,  40),

    -- flight 14: BA-117 (LHR→JFK)
    (14, 'E', 'Economy',  560.00, 180),
    (14, 'B', 'Business',1500.00,  38),

    -- flight 15: QF-001 (LHR→SYD)
    (15, 'E', 'Economy',  980.00, 210),
    (15, 'B', 'Business',2600.00,  48),
    (15, 'F', 'First',   5800.00,  14),

    -- flight 16: SQ-221 (SIN→SYD)
    (16, 'E', 'Economy',  420.00, 180),
    (16, 'B', 'Business',1100.00,  40),

    -- flight 17: AI-971 (BOM→DXB, competing)
    (17, 'E', 'Economy',  170.00, 160),
    (17, 'B', 'Business', 480.00,  32),

    -- flight 18: IX-191 (BOM→DXB, budget)
    (18, 'E', 'Economy',  145.00, 180),

    -- flight 19: AI-131 (DEL→BOM, competing)
    (19, 'E', 'Economy',   68.00, 155),
    (19, 'B', 'Business', 190.00,  24);
