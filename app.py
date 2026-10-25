"""
Dairy Milk Collection Management System
Flask + PostgreSQL (psycopg2)
Database: dairy
"""

import os
import secrets
import psycopg2
import psycopg2.extras
from flask import Flask, render_template, redirect, request, url_for, flash, g

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', secrets.token_hex(16))

# ── PostgreSQL connection config ──────────────────────────────
# Supports cloud hosting DATABASE_URL (Render, Supabase, Neon, Railway, Heroku)
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


# ── DB connection per request ─────────────────────────────────
def get_db():
    if 'db' not in g:
        if DATABASE_URL:
            g.db = psycopg2.connect(DATABASE_URL)
        else:
            g.db = psycopg2.connect(**DB_CONFIG)
    return g.db


@app.teardown_appcontext
def close_db(error):
    db = g.pop('db', None)
    if db is not None:
        db.close()


def get_cursor():
    """Return a RealDictCursor - rows accessed by column name."""
    return get_db().cursor(cursor_factory=psycopg2.extras.RealDictCursor)


def commit():
    get_db().commit()


# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────
def get_farmers_dropdown():
    cur = get_cursor()
    cur.execute("SELECT farmer_id, farmer_name, village FROM farmers WHERE is_active = TRUE ORDER BY farmer_name")
    rows = cur.fetchall()
    cur.close()
    return rows


def get_milk_types():
    cur = get_cursor()
    cur.execute("SELECT milk_type_id, type_name, base_rate FROM milk_types ORDER BY type_name")
    rows = cur.fetchall()
    cur.close()
    return rows


# ─────────────────────────────────────────────────────────────
#  Dashboard / Home
# ─────────────────────────────────────────────────────────────
@app.route('/')
def index():
    cur = get_cursor()

    # Collections overview
    cur.execute("SELECT COUNT(*) AS total, COALESCE(SUM(quantity), 0) AS litres, COALESCE(SUM(total_amount), 0) AS revenue FROM collection")
    col_stats = cur.fetchone()

    # Active entities
    cur.execute("SELECT COUNT(*) AS total FROM farmers WHERE is_active = TRUE")
    farmer_stats = cur.fetchone()

    cur.execute("SELECT COUNT(*) AS total FROM cattle WHERE is_active = TRUE")
    cattle_stats = cur.fetchone()

    cur.execute("SELECT COUNT(*) AS total FROM vehicles WHERE is_active = TRUE")
    vehicle_stats = cur.fetchone()

    cur.execute("SELECT COUNT(*) AS total FROM employees WHERE is_active = TRUE")
    emp_stats = cur.fetchone()

    # Financials
    cur.execute("SELECT COALESCE(SUM(amount_paid), 0) AS total_paid FROM payments")
    payment_stats = cur.fetchone()

    cur.execute("SELECT COALESCE(SUM(amount), 0) AS total_expenses FROM expenses")
    expense_stats = cur.fetchone()

    # Quality & Operations
    cur.execute("""
        SELECT
            COUNT(*) AS total_tests,
            COUNT(*) FILTER (WHERE result = 'Pass') AS pass_count,
            COUNT(*) FILTER (WHERE result = 'Fail') AS fail_count,
            COUNT(*) FILTER (WHERE result = 'Retest') AS retest_count
        FROM quality_tests
    """)
    quality_stats = cur.fetchone()

    # Complaints
    cur.execute("""
        SELECT
            COUNT(*) AS total_complaints,
            COUNT(*) FILTER (WHERE status = 'Open') AS open_count,
            COUNT(*) FILTER (WHERE status = 'In Progress') AS in_progress_count,
            COUNT(*) FILTER (WHERE status = 'Resolved') AS resolved_count
        FROM complaints
    """)
    complaint_stats = cur.fetchone()

    # Recent 5 collections
    cur.execute("""
        SELECT c.id, f.farmer_name, mt.type_name, c.shift, c.quantity, c.fat_percentage, c.rate, c.total_amount, c.collection_date
        FROM collection c
        JOIN farmers f ON c.farmer_id = f.farmer_id
        JOIN milk_types mt ON c.milk_type_id = mt.milk_type_id
        ORDER BY c.collection_date DESC, c.id DESC
        LIMIT 5
    """)
    recent_collections = cur.fetchall()

    cur.close()

    return render_template('index.html',
                           col_stats=col_stats,
                           farmer_stats=farmer_stats,
                           cattle_stats=cattle_stats,
                           vehicle_stats=vehicle_stats,
                           emp_stats=emp_stats,
                           payment_stats=payment_stats,
                           expense_stats=expense_stats,
                           quality_stats=quality_stats,
                           complaint_stats=complaint_stats,
                           recent_collections=recent_collections)


# ─────────────────────────────────────────────────────────────
#  1. Milk Collection Records
# ─────────────────────────────────────────────────────────────
@app.route('/view')
def view():
    cur = get_cursor()
    cur.execute("""
        SELECT
            c.id,
            f.farmer_name,
            f.village,
            mt.type_name  AS milk_type,
            c.shift,
            c.quantity,
            c.fat_percentage,
            c.rate,
            c.total_amount,
            c.collection_date,
            c.remarks
        FROM collection c
        JOIN farmers    f  ON c.farmer_id    = f.farmer_id
        JOIN milk_types mt ON c.milk_type_id = mt.milk_type_id
        ORDER BY c.collection_date DESC, c.id DESC
    """)
    records = cur.fetchall()
    cur.close()
    return render_template('view.html', records=records)


@app.route('/view/<int:id>')
def view_record(id):
    cur = get_cursor()
    cur.execute("""
        SELECT
            c.id, f.farmer_name, f.village, f.phone,
            mt.type_name AS milk_type,
            c.shift, c.quantity, c.fat_percentage, c.rate,
            c.total_amount, c.collection_date, c.remarks
        FROM collection c
        JOIN farmers    f  ON c.farmer_id    = f.farmer_id
        JOIN milk_types mt ON c.milk_type_id = mt.milk_type_id
        WHERE c.id = %s
    """, (id,))
    record = cur.fetchone()
    cur.close()
    if record is None:
        flash('Record not found!', 'danger')
        return redirect(url_for('view'))
    return render_template('view_record.html', record=record)


@app.route('/add')
def show():
    return render_template('add.html',
                           farmers=get_farmers_dropdown(),
                           milk_types=get_milk_types())


@app.route('/insert', methods=['POST'])
def insert():
    farmer_id       = request.form['farmer_id']
    milk_type_id    = request.form['milk_type_id']
    shift           = request.form['shift']
    quantity        = request.form['quantity']
    fat_percentage  = request.form['fat_percentage']
    rate            = request.form['rate']
    collection_date = request.form['collection_date']
    remarks         = request.form.get('remarks', '').strip() or None

    cur = get_cursor()
    cur.execute("""
        INSERT INTO collection
            (farmer_id, milk_type_id, shift, quantity, fat_percentage, rate, collection_date, remarks)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, (farmer_id, milk_type_id, shift, quantity, fat_percentage, rate, collection_date, remarks))
    commit()
    cur.close()
    flash('Milk collection record added successfully!', 'success')
    return redirect(url_for('view'))


@app.route('/edit/<int:id>')
def edit(id):
    cur = get_cursor()
    cur.execute("""
        SELECT c.*, f.farmer_name, mt.type_name
        FROM collection c
        JOIN farmers    f  ON c.farmer_id    = f.farmer_id
        JOIN milk_types mt ON c.milk_type_id = mt.milk_type_id
        WHERE c.id = %s
    """, (id,))
    record = cur.fetchone()
    cur.close()
    if record is None:
        flash('Record not found!', 'danger')
        return redirect(url_for('view'))
    return render_template('edit.html',
                           record=record,
                           farmers=get_farmers_dropdown(),
                           milk_types=get_milk_types())


@app.route('/update/<int:id>', methods=['POST'])
def update(id):
    farmer_id       = request.form['farmer_id']
    milk_type_id    = request.form['milk_type_id']
    shift           = request.form['shift']
    quantity        = request.form['quantity']
    fat_percentage  = request.form['fat_percentage']
    rate            = request.form['rate']
    collection_date = request.form['collection_date']
    remarks         = request.form.get('remarks', '').strip() or None

    cur = get_cursor()
    cur.execute("""
        UPDATE collection
        SET farmer_id       = %s,
            milk_type_id    = %s,
            shift           = %s,
            quantity        = %s,
            fat_percentage  = %s,
            rate            = %s,
            collection_date = %s,
            remarks         = %s
        WHERE id = %s
    """, (farmer_id, milk_type_id, shift, quantity, fat_percentage, rate, collection_date, remarks, id))
    commit()
    cur.close()
    flash('Record updated successfully!', 'success')
    return redirect(url_for('view'))


@app.route('/delete/<int:id>', methods=['POST'])
def delete(id):
    cur = get_cursor()
    cur.execute("DELETE FROM collection WHERE id = %s", (id,))
    commit()
    cur.close()
    flash('Record deleted successfully.', 'warning')
    return redirect(url_for('view'))


# ─────────────────────────────────────────────────────────────
#  2. Farmers
# ─────────────────────────────────────────────────────────────
@app.route('/farmers')
def farmers():
    cur = get_cursor()
    cur.execute("""
        SELECT f.*,
               COUNT(c.id)                      AS total_collections,
               COALESCE(SUM(c.quantity), 0)     AS total_litres,
               COALESCE(SUM(c.total_amount), 0) AS total_revenue
        FROM farmers f
        LEFT JOIN collection c ON f.farmer_id = c.farmer_id
        GROUP BY f.farmer_id
        ORDER BY f.farmer_id
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('farmers.html', farmers=rows)


# ─────────────────────────────────────────────────────────────
#  3. Quality Tests
# ─────────────────────────────────────────────────────────────
@app.route('/quality')
def quality():
    cur = get_cursor()
    cur.execute("""
        SELECT
            qt.test_id,
            qt.collection_id,
            qt.tested_by,
            qt.fat_pct,
            qt.snf_pct,
            qt.clr,
            qt.temperature_c,
            qt.result,
            qt.test_date,
            c.collection_date,
            c.shift,
            c.quantity,
            f.farmer_name
        FROM quality_tests qt
        JOIN collection c ON qt.collection_id = c.id
        JOIN farmers    f ON c.farmer_id       = f.farmer_id
        ORDER BY qt.test_date DESC, qt.test_id DESC
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('quality.html', tests=rows)


# ─────────────────────────────────────────────────────────────
#  4. Payments
# ─────────────────────────────────────────────────────────────
@app.route('/payments')
def payments():
    cur = get_cursor()
    cur.execute("""
        SELECT
            p.payment_id,
            p.farmer_id,
            f.farmer_name,
            f.village,
            p.period_from,
            p.period_to,
            p.amount_paid,
            p.payment_date,
            p.payment_mode
        FROM payments p
        JOIN farmers f ON p.farmer_id = f.farmer_id
        ORDER BY p.payment_date DESC, p.payment_id DESC
    """)
    rows = cur.fetchall()

    cur.execute("SELECT COALESCE(SUM(amount_paid), 0) AS total_paid FROM payments")
    total_paid = cur.fetchone()['total_paid']

    cur.close()
    return render_template('payments.html', payments=rows, total_paid=total_paid)


# ─────────────────────────────────────────────────────────────
#  5. Cattle
# ─────────────────────────────────────────────────────────────
@app.route('/cattle')
def cattle():
    cur = get_cursor()
    cur.execute("""
        SELECT
            ca.cattle_id,
            ca.farmer_id,
            f.farmer_name,
            f.village,
            ca.animal_type,
            ca.breed,
            ca.age_years,
            ca.tag_number,
            ca.is_active
        FROM cattle ca
        JOIN farmers f ON ca.farmer_id = f.farmer_id
        ORDER BY ca.cattle_id
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('cattle.html', cattle=rows)


# ─────────────────────────────────────────────────────────────
#  6. Vehicles
# ─────────────────────────────────────────────────────────────
@app.route('/vehicles')
def vehicles():
    cur = get_cursor()
    cur.execute("""
        SELECT
            vehicle_id,
            vehicle_no,
            vehicle_type,
            capacity_liters,
            driver_name,
            driver_phone,
            is_active
        FROM vehicles
        ORDER BY vehicle_id
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('vehicles.html', vehicles=rows)


# ─────────────────────────────────────────────────────────────
#  7. Employees
# ─────────────────────────────────────────────────────────────
@app.route('/employees')
def employees():
    cur = get_cursor()
    cur.execute("""
        SELECT
            emp_id,
            emp_name,
            role,
            phone,
            salary,
            join_date,
            is_active
        FROM employees
        ORDER BY emp_id
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('employees.html', employees=rows)


# ─────────────────────────────────────────────────────────────
#  8. Complaints
# ─────────────────────────────────────────────────────────────
@app.route('/complaints')
def complaints():
    cur = get_cursor()
    cur.execute("""
        SELECT
            co.complaint_id,
            co.farmer_id,
            f.farmer_name,
            f.village,
            co.complaint_type,
            co.description,
            co.status,
            co.filed_date,
            co.resolved_date
        FROM complaints co
        JOIN farmers f ON co.farmer_id = f.farmer_id
        ORDER BY co.filed_date DESC, co.complaint_id DESC
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('complaints.html', complaints=rows)


# ─────────────────────────────────────────────────────────────
#  9. Expenses
# ─────────────────────────────────────────────────────────────
@app.route('/expenses')
def expenses():
    cur = get_cursor()
    cur.execute("""
        SELECT
            expense_id,
            category,
            description,
            amount,
            expense_date,
            paid_to,
            payment_mode
        FROM expenses
        ORDER BY expense_date DESC, expense_id DESC
    """)
    rows = cur.fetchall()

    cur.execute("SELECT COALESCE(SUM(amount), 0) AS total_expense FROM expenses")
    total_expense = cur.fetchone()['total_expense']

    cur.close()
    return render_template('expenses.html', expenses=rows, total_expense=total_expense)


# ─────────────────────────────────────────────────────────────
#  10. Daily Summary View
# ─────────────────────────────────────────────────────────────
@app.route('/summary')
def summary():
    cur = get_cursor()
    cur.execute("""
        SELECT *
        FROM v_daily_summary
        ORDER BY collection_date DESC, shift ASC
    """)
    rows = cur.fetchall()
    cur.close()
    return render_template('summary.html', rows=rows)


# ─────────────────────────────────────────────────────────────
#  Cloud Hosting Helper: One-click DB Initializer
# ─────────────────────────────────────────────────────────────
@app.route('/init-db')
def init_db():
    schema_path = os.path.join(os.path.dirname(__file__), 'schema.sql')
    if not os.path.exists(schema_path):
        return "schema.sql not found!", 404
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            sql_script = f.read()
        db = get_db()
        with db.cursor() as cur:
            cur.execute(sql_script)
        db.commit()
        flash('Database initialized successfully with all 10 tables and sample data!', 'success')
        return redirect(url_for('index'))
    except Exception as e:
        return f"Database initialization failed: {str(e)}", 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'True').lower() in ('true', '1')
    app.run(host='0.0.0.0', port=port, debug=debug)
