#!/usr/bin/env python3
"""
setup_db.py
One-time script to create the ERP database and seed it with dummy data.
Run this ONCE before starting the Flask app.

Usage:
  python setup_db.py
"""
import os
import sys
import psycopg2
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", 5432))
DB_NAME = os.getenv("DB_NAME", "erp_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASSWORD", "")


def run_sql_file(cursor, filepath: str):
    with open(filepath, "r") as f:
        sql = f.read()
    cursor.execute(sql)
    print(f"  ✓ Executed {filepath}")


def main():
    print("=" * 55)
    print("  ERP Chatbot — Database Setup")
    print("=" * 55)

    # Connect to postgres (default db) to create erp_db if needed
    try:
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT,
            dbname="postgres",
            user=DB_USER, password=DB_PASS
        )
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute(f"SELECT 1 FROM pg_database WHERE datname = '{DB_NAME}'")
        if not cur.fetchone():
            cur.execute(f"CREATE DATABASE {DB_NAME}")
            print(f"  ✓ Created database '{DB_NAME}'")
        else:
            print(f"  ✓ Database '{DB_NAME}' already exists")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"\n  ✗ Failed to connect to PostgreSQL: {e}")
        print("    Make sure PostgreSQL is running and credentials in .env are correct.")
        sys.exit(1)

    # Now connect to erp_db and run schema + seed
    try:
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER, password=DB_PASS
        )
        conn.autocommit = False
        cur = conn.cursor()

        print("\n  Loading schema...")
        run_sql_file(cur, "db/schema.sql")

        print("  Seeding data...")
        run_sql_file(cur, "db/seed.sql")

        conn.commit()
        cur.close()
        conn.close()

        print("\n  ✓ Database setup complete!")
        print(f"\n  You can now run:  python app.py")
        print(f"  Then open:       http://localhost:5000\n")

    except Exception as e:
        conn.rollback()
        print(f"\n  ✗ Error during setup: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
