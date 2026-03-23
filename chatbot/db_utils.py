"""
db_utils.py
PostgreSQL connection pool and query execution utilities for the ERP chatbot.
"""
import os
import psycopg2
from psycopg2 import pool, extras
from dotenv import load_dotenv

# Load .env IMMEDIATELY at import time — must happen before any os.getenv() call
load_dotenv(override=True)


# Connection pool (min 1, max 10 connections for scalability)

_pool = None


def get_pool() -> pool.ThreadedConnectionPool:
    global _pool
    if _pool is None:
        db_host = os.getenv("DB_HOST", "localhost")
        db_port = int(os.getenv("DB_PORT", 5432))
        db_name = os.getenv("DB_NAME", "erpdb")
        db_user = os.getenv("DB_USER", "postgres")
        db_pass = os.getenv("DB_PASSWORD", "")

        # Debug — remove after confirming it works
        print(f"[DB] Connecting to {db_user}@{db_host}:{db_port}/{db_name}  password_set={'yes' if db_pass else 'NO - CHECK .env'}")

        _pool = pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=10,
            host=db_host,
            port=db_port,
            dbname=db_name,
            user=db_user,
            password=db_pass,
        )
    return _pool


def execute_query(sql: str, params=None) -> dict:
    """
    Execute a SQL query and return:
      {
        "columns": [...],
        "rows":    [...],          # list of dicts
        "rowcount": int,
        "error":   str | None
      }
    """
    conn = None
    result = {"columns": [], "rows": [], "rowcount": 0, "error": None}
    try:
        conn = get_pool().getconn()
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            conn.commit()
            if cur.description:
                result["columns"] = [desc[0] for desc in cur.description]
                rows = cur.fetchall()
                result["rows"] = [dict(r) for r in rows]
                result["rowcount"] = len(rows)
            else:
                result["rowcount"] = cur.rowcount
    except Exception as exc:
        if conn:
            conn.rollback()
        result["error"] = str(exc)
    finally:
        if conn:
            get_pool().putconn(conn)
    return result


def get_schema_description() -> str:
    """
    Build a concise schema description so the LLM understands the database.
    This is injected into the system prompt.
    """
    schema = """
You are connected to an ERP PostgreSQL database. Here is the full schema:

## HR Module
- **departments** (department_id, name, location, budget, head_employee_id, created_at)
- **employees** (employee_id, first_name, last_name, email, phone, hire_date, job_title, department_id, manager_id, salary, employment_type[full-time/part-time/contract/intern], status[active/inactive/terminated], created_at)
- **attendance** (attendance_id, employee_id, work_date, check_in, check_out, hours_worked, status[present/absent/half-day/remote])
- **leave_requests** (leave_id, employee_id, leave_type[sick/casual/earned/maternity/paternity/unpaid], start_date, end_date, reason, status[pending/approved/rejected], approved_by, applied_at)
- **payroll** (payroll_id, employee_id, pay_period, basic_salary, allowances, deductions, tax, net_pay, paid_on, status[pending/paid/failed])

## Inventory Module
- **warehouses** (warehouse_id, name, location, capacity, manager_id)
- **product_categories** (category_id, name, parent_id, description)
- **products** (product_id, sku, name, description, category_id, unit_price, cost_price, qty_in_stock, reorder_level, warehouse_id, is_active, created_at)
- **stock_movements** (movement_id, product_id, movement_type[purchase/sale/adjustment/transfer/return], quantity, reference_id, reference_type, moved_at, notes)

## Sales Module
- **customers** (customer_id, name, email, phone, address, city, state, country, credit_limit, assigned_rep, created_at)
- **sales_orders** (order_id, customer_id, order_date, expected_delivery, status[pending/confirmed/processing/shipped/delivered/cancelled], total_amount, discount, tax_amount, created_by, notes)
- **sales_order_items** (item_id, order_id, product_id, quantity, unit_price, line_total)
- **invoices** (invoice_id, order_id, customer_id, invoice_date, due_date, amount, amount_paid, status[unpaid/partial/paid/overdue/cancelled], payment_method)
- **invoice_items** (item_id, invoice_id, description, quantity, unit_price, amount)

## Procurement Module
- **suppliers** (supplier_id, name, contact_name, email, phone, city, country, payment_terms, rating, is_active)
- **purchase_orders** (po_id, supplier_id, po_date, expected_date, status[draft/sent/confirmed/received/cancelled], total_amount, created_by, notes)
- **purchase_order_items** (item_id, po_id, product_id, quantity, unit_cost, line_total)

## Finance Module
- **accounts** (account_id, account_code, name, account_type[asset/liability/equity/revenue/expense], balance, is_active)
- **journal_entries** (entry_id, entry_date, description, reference, created_by, posted)
- **journal_lines** (line_id, entry_id, account_id, debit, credit, description)

## CRM Module
- **crm_leads** (lead_id, name, company, email, phone, source, status[new/contacted/qualified/proposal/won/lost], estimated_value, assigned_to, notes, created_at)

## Key Relationships
- employees.department_id → departments.department_id
- employees.manager_id → employees.employee_id (self-referential)
- sales_orders.customer_id → customers.customer_id
- sales_order_items.order_id → sales_orders.order_id
- sales_order_items.product_id → products.product_id
- invoices.order_id → sales_orders.order_id
- purchase_orders.supplier_id → suppliers.supplier_id
- purchase_order_items.po_id → purchase_orders.po_id
- products.category_id → product_categories.category_id
- journal_lines.account_id → accounts.account_id

## Rules
- Always use table aliases for clarity in JOINs.
- Limit results to 100 rows unless the user asks for more.
- For date arithmetic, use PostgreSQL syntax (e.g., CURRENT_DATE, INTERVAL).
- Never use DROP, DELETE, UPDATE, INSERT, TRUNCATE, ALTER — only SELECT.
- If a question is ambiguous, write the most likely intended query.
"""
    return schema.strip()
