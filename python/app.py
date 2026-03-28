"""
Global Flight Route Optimization System
File: app.py
Description: Streamlit web interface
Run: streamlit run app.py
Install: pip install streamlit psycopg2-binary pandas
"""

import streamlit as st
import psycopg2
import pandas as pd


# ─────────────────────────────────────────
# PAGE CONFIG
# ─────────────────────────────────────────
st.set_page_config(
    page_title="Flight Route Optimizer",
    page_icon="✈️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ─────────────────────────────────────────
# DATABASE CONNECTION
# ─────────────────────────────────────────
@st.cache_resource
def get_connection():
    """Create cached database connection"""
    return psycopg2.connect(
        host     = "localhost",
        database = "flight_system",
        user     = "postgres",
        password = "admin",    # ← CHANGE THIS
        port     = "5432"
    )

@st.cache_data(ttl=300)
def run_query(query, params=None):
    """Run a query and return results as DataFrame"""
    try:
        conn = get_connection()
        return pd.read_sql_query(query, conn, params=params)
    except Exception as e:
        st.error(f"Database error: {e}")
        return pd.DataFrame()


# ─────────────────────────────────────────
# DATA LOADERS
# ─────────────────────────────────────────
@st.cache_data(ttl=600)
def load_airports():
    query = """
        SELECT
            a.airport_code,
            a.airport_name,
            ci.city_name,
            co.country_name,
            a.latitude,
            a.longitude
        FROM airports a
        JOIN cities ci    ON a.city_id       = ci.city_id
        JOIN countries co ON ci.country_code = co.country_code
        WHERE a.is_active = TRUE
        ORDER BY ci.city_name;
    """
    return run_query(query)


def find_routes(origin, destination, cabin_class, optimize_by):
    order_map = {
        'Cheapest'   : 'total_cost ASC',
        'Fastest'    : 'total_duration ASC',
        'Fewest Stops': 'num_stops ASC, total_cost ASC'
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
                rf.path || ' → ' || f.flight_number
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
        LIMIT 10;
    """
    params = {
        'origin'      : origin,
        'destination' : destination,
        'cabin_class' : cabin_class
    }
    return run_query(query, params)


def load_pricing_comparison():
    query = """
        SELECT
            f.flight_number,
            f.origin_airport || ' → ' || f.dest_airport AS route,
            MAX(CASE WHEN fp.class_code = 'E' THEN fp.price_usd END) AS economy,
            MAX(CASE WHEN fp.class_code = 'B' THEN fp.price_usd END) AS business,
            MAX(CASE WHEN fp.class_code = 'F' THEN fp.price_usd END) AS first_class
        FROM flights f
        JOIN flight_pricing fp ON f.flight_id = fp.flight_id
        GROUP BY f.flight_number, f.origin_airport, f.dest_airport
        ORDER BY f.flight_number;
    """
    return run_query(query)


def load_airline_ranking():
    query = """
        SELECT
            f.origin_airport || ' → ' || f.dest_airport AS route,
            f.flight_number,
            al.airline_name,
            fp.price_usd,
            RANK() OVER (
                PARTITION BY f.origin_airport, f.dest_airport
                ORDER BY fp.price_usd ASC
            ) AS price_rank
        FROM flights f
        JOIN flight_pricing fp  ON f.flight_id    = fp.flight_id
        JOIN airlines al        ON f.airline_code = al.airline_code
        WHERE fp.class_code = 'E'
        ORDER BY route, price_rank;
    """
    return run_query(query)


# ─────────────────────────────────────────
# UI — SIDEBAR
# ─────────────────────────────────────────
with st.sidebar:
    st.image("https://img.icons8.com/fluency/96/airplane-mode-on.png", width=80)
    st.title("Flight Optimizer")
    st.markdown("---")

    st.markdown("### 🗺️ Search Settings")

    airports_df = load_airports()

    if airports_df.empty:
        st.error("Cannot connect to database. Check your password in app.py")
        st.stop()

    # Build airport options
    airport_options = {
        f"{row['airport_code']} — {row['city_name']}, {row['country_name']}": row['airport_code']
        for _, row in airports_df.iterrows()
    }
    airport_labels = list(airport_options.keys())

    origin_label = st.selectbox(
        "🛫 Origin Airport",
        airport_labels,
        index=0
    )

    destination_label = st.selectbox(
        "🛬 Destination Airport",
        airport_labels,
        index=3
    )

    cabin_class = st.radio(
        "💺 Cabin Class",
        options=['E', 'B', 'F'],
        format_func=lambda x: {'E': 'Economy', 'B': 'Business', 'F': 'First Class'}[x],
        horizontal=True
    )

    optimize_by = st.selectbox(
        "🎯 Optimize By",
        ['Cheapest', 'Fastest', 'Fewest Stops']
    )

    search_btn = st.button("🔍 Find Routes", type="primary", use_container_width=True)

    st.markdown("---")
    st.markdown("**Tech Stack**")
    st.markdown("🐘 PostgreSQL 16")
    st.markdown("🐍 Python + Streamlit")
    st.markdown("📊 Recursive CTEs")


# ─────────────────────────────────────────
# UI — MAIN CONTENT
# ─────────────────────────────────────────
origin      = airport_options[origin_label]
destination = airport_options[destination_label]

st.title("✈️ Global Flight Route Optimization System")
st.markdown(
    "Find optimal flight routes between airports worldwide using "
    "**PostgreSQL recursive CTEs** and advanced graph traversal."
)

# ── TAB LAYOUT ──────────────────────────
tab1, tab2, tab3, tab4 = st.tabs([
    "🔍 Route Finder",
    "💰 Price Comparison",
    "🏆 Airline Rankings",
    "🗺️ Airport Map"
])


# ── TAB 1: ROUTE FINDER ─────────────────
with tab1:
    if origin == destination:
        st.warning("⚠️ Origin and destination cannot be the same airport.")

    elif search_btn or True:  # Show on load with defaults
        class_names = {'E': 'Economy', 'B': 'Business', 'F': 'First Class'}

        col1, col2, col3 = st.columns(3)
        col1.metric("From", origin)
        col2.metric("To", destination)
        col3.metric("Class", class_names[cabin_class])

        with st.spinner("Finding optimal routes..."):
            routes_df = find_routes(origin, destination, cabin_class, optimize_by)

        if routes_df.empty:
            st.info(
                f"No routes found from **{origin}** to **{destination}** "
                f"in **{class_names[cabin_class]}** class.\n\n"
                "Try a different cabin class or check the airport codes."
            )
        else:
            st.success(f"Found **{len(routes_df)}** route(s) — sorted by **{optimize_by}**")

            for i, row in routes_df.iterrows():
                hrs  = int(row['duration_mins']) // 60
                mins = int(row['duration_mins']) % 60
                stops_label = "Direct ✅" if row['num_stops'] == 0 else f"{int(row['num_stops'])} Stop(s)"

                with st.expander(
                    f"#{i+1}  {row['route']}  —  "
                    f"${row['price_usd']:,.2f}  |  {hrs}h {mins}m  |  {stops_label}",
                    expanded=(i == 0)
                ):
                    c1, c2, c3, c4 = st.columns(4)
                    c1.metric("💵 Total Price", f"${row['price_usd']:,.2f}")
                    c2.metric("⏱️ Duration", f"{hrs}h {mins}m")
                    c3.metric("🛑 Stops", stops_label)
                    c4.metric("✈️ Flights", row['route'])

            # Summary chart
            if len(routes_df) > 1:
                st.markdown("#### Price Comparison")
                chart_df = routes_df[['route', 'price_usd']].copy()
                chart_df = chart_df.set_index('route')
                st.bar_chart(chart_df)


# ── TAB 2: PRICE COMPARISON ─────────────
with tab2:
    st.subheader("💰 Price Comparison Across All Classes")
    st.markdown(
        "Each row shows Economy / Business / First Class prices for the same flight. "
        "`None` means that class is not available on that flight."
    )

    with st.spinner("Loading pricing data..."):
        pricing_df = load_pricing_comparison()

    if not pricing_df.empty:
        # Format prices
        for col in ['economy', 'business', 'first_class']:
            pricing_df[col] = pricing_df[col].apply(
                lambda x: f"${x:,.2f}" if pd.notna(x) else "—"
            )
        pricing_df.columns = ['Flight', 'Route', 'Economy', 'Business', 'First Class']
        st.dataframe(pricing_df, use_container_width=True, hide_index=True)


# ── TAB 3: AIRLINE RANKINGS ─────────────
with tab3:
    st.subheader("🏆 Airline Rankings by Route (Economy Class)")
    st.markdown(
        "Airlines ranked by price within each route using **SQL Window Functions** "
        "(RANK() OVER PARTITION BY). Rank 1 = cheapest on that route."
    )

    with st.spinner("Loading rankings..."):
        ranking_df = load_airline_ranking()

    if not ranking_df.empty:
        # Highlight rank 1
        ranking_df['price_usd'] = ranking_df['price_usd'].apply(lambda x: f"${x:,.2f}")
        ranking_df['price_rank'] = ranking_df['price_rank'].apply(
            lambda x: f"🥇 {x}" if x == 1 else f"#{x}"
        )
        ranking_df.columns = ['Route', 'Flight', 'Airline', 'Price', 'Rank']
        st.dataframe(ranking_df, use_container_width=True, hide_index=True)


# ── TAB 4: AIRPORT MAP ──────────────────
with tab4:
    st.subheader("🗺️ Airport Locations")
    st.markdown("All airports in the system plotted on a world map.")

    if not airports_df.empty:
        map_df = airports_df[['latitude', 'longitude', 'airport_code', 'city_name']].copy()
        map_df = map_df.rename(columns={'latitude': 'lat', 'longitude': 'lon'})
        st.map(map_df, zoom=1)

        st.markdown("#### All Airports")
        display_airports = airports_df[
            ['airport_code', 'airport_name', 'city_name', 'country_name']
        ].copy()
        display_airports.columns = ['Code', 'Airport', 'City', 'Country']
        st.dataframe(display_airports, use_container_width=True, hide_index=True)


# ─────────────────────────────────────────
# FOOTER
# ─────────────────────────────────────────
st.markdown("---")
st.markdown(
    "<div style='text-align:center; color:gray; font-size:0.85em'>"
    "Global Flight Route Optimization System &nbsp;|&nbsp; "
    "PostgreSQL 16 · Python · Streamlit &nbsp;|&nbsp; "
    "Built as a DBMS project"
    "</div>",
    unsafe_allow_html=True
)
