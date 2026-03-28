# ✈️ Global Flight Route Optimization System

A database-driven system that models global airports and flight routes,
computing optimal paths between any two locations using advanced SQL and Python.

## 🎯 Core Features

- **Multi-hop route finding** using PostgreSQL recursive CTEs (up to 3 stops)
- **Three optimization modes**: Cheapest / Fastest / Fewest Stops
- **Multi-cabin class support**: Economy, Business, First Class
- **Competitive airline ranking** using SQL Window Functions
- **Price comparison** across classes using conditional aggregation
- **Interactive web UI** built with Streamlit
- **Cycle-safe graph traversal** using visited-array pattern (BFS equivalent)

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16 |
| Language | Python 3.11 |
| Web UI | Streamlit |
| DB Driver | psycopg2 |
| Data | pandas |

## 🗄️ Database Design

**6 normalized tables (3NF):**

```
countries → cities → airports → flights → flight_pricing
                  ↗
airlines ─────────
```

- 15+ constraints (PRIMARY KEY, FOREIGN KEY, CHECK, UNIQUE, NOT NULL)
- 5 partial composite indexes for query optimization
- Regular VIEW and MATERIALIZED VIEW for route summaries
- Soft delete pattern (is_active flag) throughout

## 🚀 Setup Instructions

### 1. Database Setup
```bash
# Open pgAdmin and run these files in order:
database/01_schema.sql      # Creates all 6 tables
database/02_seed_data.sql   # Inserts sample data
database/03_indexes.sql     # Creates performance indexes
database/04_views.sql       # Creates views
```

### 2. Python Setup
```bash
pip install streamlit psycopg2-binary pandas tabulate
```

### 3. Update Password
Edit `python/app.py` and `python/route_finder.py`:
```python
"password": "your_actual_password_here"
```

### 4. Run Web App
```bash
cd python
streamlit run app.py
```

### 5. Run CLI Version
```bash
cd python
python route_finder.py
```

## 📊 Key SQL Concepts Demonstrated

- **Recursive CTEs** for graph traversal (multi-hop route finding)
- **Window Functions** (RANK, DENSE_RANK, PERCENT_RANK)
- **Conditional Aggregation** (pivot pricing data)
- **Partial Indexing** and EXPLAIN ANALYZE optimization
- **ACID Transactions** and constraint-driven data integrity
- **Normalization** (1NF → 2NF → 3NF design decisions)

## 💡 How the Route Finder Works

```
Base case (iteration 0):
  Find all direct flights from BOM
  Seed: BOM→DEL, BOM→DXB, BOM→BLR, BOM→SIN

Recursive case (iterations 1-3):
  Extend each path by one more flight
  Track visited airports to prevent cycles
  Accumulate cost and duration

Final SELECT:
  Filter only paths reaching destination
  Order by chosen optimization criteria
```

This is equivalent to **Breadth-First Search** on a directed graph
where airports are nodes and flights are edges.

## 📁 Project Structure

```
flight-route-optimizer/
├── database/
│   ├── 01_schema.sql       # All CREATE TABLE statements
│   ├── 02_seed_data.sql    # Sample data (8 countries, 10 airports, 19 flights)
│   ├── 03_indexes.sql      # Performance indexes
│   ├── 04_views.sql        # Regular and materialized views
│   └── 05_queries.sql      # All advanced SQL queries
├── python/
│   ├── app.py              # Streamlit web application
│   └── route_finder.py     # CLI route finder
├── docs/
│   └── (add screenshots here)
├── README.md
└── .gitignore
```

## 🎤 Interview Talking Points

1. **Why PostgreSQL?** Recursive CTEs for graph traversal — not available in MySQL, impossible in MongoDB without application-level logic
2. **Why separate flight_pricing?** 3NF normalization — price depends on both flight AND class, not just flight
3. **How do you prevent infinite loops?** Visited-array pattern + depth limit — equivalent to BFS marked-array
4. **What does EXPLAIN ANALYZE show?** Execution plan — Seq Scan vs Index Scan, actual rows, execution time
5. **Why partial indexes?** Only index active flights — 20-30% smaller index, faster lookups

---
Built as a DBMS capstone project | PostgreSQL · Python · Streamlit
