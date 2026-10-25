"""
Database Initialization Script for Dairy Milk Collection Management System
Creates all 10 tables, view, and seeds 20 sample rows per table.
Usage:
    python init_db.py
"""

import os
import psycopg2

# Read configuration from environment (supports cloud DATABASE_URL)
DATABASE_URL = os.environ.get('DATABASE_URL')
if DATABASE_URL and DATABASE_URL.startswith('postgres://'):
    DATABASE_URL = DATABASE_URL.replace('postgres://', 'postgresql://', 1)

DB_CONFIG = {
    'dbname':   os.environ.get('DB_NAME', 'dairy'),
    'user':     os.environ.get('DB_USER', 'postgres'),
    'password': os.environ.get('DB_PASSWORD', '7499644158'),
    'host':     os.environ.get('DB_HOST', 'localhost'),
    'port':     int(os.environ.get('DB_PORT', 5432))
}


def main():
    print("Connecting to PostgreSQL database...")
    if DATABASE_URL:
        print("Using DATABASE_URL connection string.")
        conn = psycopg2.connect(DATABASE_URL)
    else:
        print(f"Using local connection: host={DB_CONFIG['host']}, dbname={DB_CONFIG['dbname']}, user={DB_CONFIG['user']}")
        conn = psycopg2.connect(**DB_CONFIG)

    schema_file = os.path.join(os.path.dirname(__file__), 'schema.sql')
    print(f"Reading schema from: {schema_file}")
    with open(schema_file, 'r', encoding='utf-8') as f:
        sql = f.read()

    with conn.cursor() as cur:
        print("Executing schema and inserting 20 sample rows per table...")
        cur.execute(sql)

    conn.commit()
    conn.close()
    print("Database initialization completed successfully!")


if __name__ == '__main__':
    main()
