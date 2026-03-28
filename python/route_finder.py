"""
Global Flight Route Optimization System
File: route_finder.py
Description: Python interface to PostgreSQL route optimizer
Run: python route_finder.py
"""

import psycopg2
import pandas as pd
from tabulate import tabulate


# ─────────────────────────────────────────
# DATABASE CONNECTION
# Update password to match your PostgreSQL setup
# ─────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "database": "flight_system",
    "user":     "postgres",
    "password": "admin",   # ← CHANGE THIS
    "port":     "5432"
}

def create_connection():
    """Create and return a PostgreSQL connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except psycopg2.OperationalError as e:
        print(f"❌ Connection failed: {e}")
        return None


# ─────────────────────────────────────────
# CORE ROUTE FINDER
# ─────────────────────────────────────────
def find_routes(origin, destination, cabin_class='E', optimize_by='cost'):
    """
    Find optimal flight routes between two airports.

    Parameters:
        origin      : IATA code e.g. 'BOM'
        destination : IATA code e.g. 'LHR'
        cabin_class : 'E'=Economy, 'B'=Business, 'F'=First
        optimize_by : 'cost', 'duration', or 'stops'

    Returns:
        pandas DataFrame with route results
    """
    order_map = {
        'cost'     : 'total_cost ASC',
        'duration' : 'total_duration ASC',
        'stops'    : 'num_stops ASC, total_cost ASC'
    }
    order_clause = order_map.get(optimize_by, 'total_cost ASC')

    query = f"""
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
            WHERE f.origin_airport = %(origin)s
              AND f.is_active      = TRUE
              AND fp.class_code    = %(cabin_class)s

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
              AND fp.class_code  = %(cabin_class)s
              AND NOT (f.dest_airport = ANY(rf.visited))
        )
        SELECT
            path            AS route,
            total_cost      AS price_usd,
            total_duration  AS duration_mins,
            num_stops
        FROM route_finder
        WHERE current_dest = %(destination)s
        ORDER BY {order_clause}
        LIMIT 5;
    """

    params = {
        'origin'      : origin,
        'destination' : destination,
        'cabin_class' : cabin_class
    }

    try:
        conn = create_connection()
        if conn is None:
            return None
        df = pd.read_sql_query(query, conn, params=params)
        conn.close()
        return df
    except Exception as e:
        print(f"❌ Query failed: {e}")
        return None


# ─────────────────────────────────────────
# DISPLAY FORMATTER
# ─────────────────────────────────────────
def display_routes(origin, destination, cabin_class='E', optimize_by='cost'):
    """Display routes in a clean formatted table"""

    class_names = {
        'E': 'Economy',
        'B': 'Business',
        'F': 'First Class'
    }

    print(f"\n{'='*60}")
    print(f"  ✈  Routes : {origin}  →  {destination}")
    print(f"     Class  : {class_names.get(cabin_class, cabin_class)}")
    print(f"     Sorted : by {optimize_by}")
    print(f"{'='*60}")

    df = find_routes(origin, destination, cabin_class, optimize_by)

    if df is None or df.empty:
        print("  No routes found for this combination.")
        print("  Check airport codes or try a different class.\n")
        return

    # Format columns for display
    df['Price']    = df['price_usd'].apply(lambda x: f"${x:,.2f}")
    df['Duration'] = df['duration_mins'].apply(
        lambda x: f"{x//60}h {x%60}m"
    )
    df['Stops']    = df['num_stops'].apply(
        lambda x: "Direct" if x == 0 else f"{x} stop(s)"
    )

    display_df = df[['route', 'Price', 'Duration', 'Stops']].copy()
    display_df.columns = ['Route', 'Price', 'Duration', 'Stops']
    display_df.index = range(1, len(display_df) + 1)

    print(tabulate(display_df, headers='keys', tablefmt='rounded_outline'))
    print()


# ─────────────────────────────────────────
# AIRPORT INFO LOOKUP
# ─────────────────────────────────────────
def get_all_airports():
    """Return all active airports with city and country"""
    query = """
        SELECT
            a.airport_code,
            a.airport_name,
            ci.city_name,
            co.country_name,
            co.continent
        FROM airports a
        JOIN cities ci    ON a.city_id       = ci.city_id
        JOIN countries co ON ci.country_code = co.country_code
        WHERE a.is_active = TRUE
        ORDER BY co.continent, ci.city_name;
    """
    try:
        conn = create_connection()
        if conn is None:
            return None
        df = pd.read_sql_query(query, conn)
        conn.close()
        return df
    except Exception as e:
        print(f"❌ Query failed: {e}")
        return None


# ─────────────────────────────────────────
# INTERACTIVE SEARCH
# ─────────────────────────────────────────
def interactive_search():
    """Let user search for routes interactively via terminal"""

    print("\n" + "="*60)
    print("  🛫  Global Flight Route Optimization System")
    print("="*60)

    # Show available airports
    print("\nAvailable airports:")
    airports_df = get_all_airports()
    if airports_df is not None:
        for _, row in airports_df.iterrows():
            print(f"  {row['airport_code']}  |  {row['city_name']}, {row['country_name']}")

    print()
    origin      = input("Enter origin airport code      (e.g. BOM): ").upper().strip()
    destination = input("Enter destination airport code (e.g. LHR): ").upper().strip()

    print("\nCabin class options: E=Economy  B=Business  F=First")
    cabin_class = input("Enter cabin class              (default E): ").upper().strip() or 'E'

    print("\nOptimize by: cost  /  duration  /  stops")
    optimize_by = input("Enter optimization preference (default cost): ").lower().strip() or 'cost'

    display_routes(origin, destination, cabin_class, optimize_by)

    # Ask if user wants to search again
    again = input("Search again? (y/n): ").lower().strip()
    if again == 'y':
        interactive_search()


# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────
if __name__ == "__main__":
    interactive_search()
