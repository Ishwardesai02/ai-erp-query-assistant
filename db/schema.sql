-- ============================================================
--  ERP DATABASE SCHEMA
--  Covers: HR, Finance, Inventory, Sales, Procurement, CRM
-- ============================================================

-- Drop in reverse dependency order
DROP TABLE IF EXISTS payroll CASCADE;
DROP TABLE IF EXISTS leave_requests CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

DROP TABLE IF EXISTS invoice_items CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS sales_order_items CASCADE;
DROP TABLE IF EXISTS sales_orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;

DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;

DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS journal_entries CASCADE;
DROP TABLE IF EXISTS journal_lines CASCADE;

DROP TABLE IF EXISTS crm_leads CASCADE;

-- ============================================================
--  HR MODULE
-- ============================================================

CREATE TABLE departments (
    department_id   SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    location        VARCHAR(100),
    budget          NUMERIC(15,2) DEFAULT 0,
    head_employee_id INT,          -- FK added after employees
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE employees (
    employee_id     SERIAL PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(120) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    hire_date       DATE NOT NULL,
    job_title       VARCHAR(100),
    department_id   INT REFERENCES departments(department_id),
    manager_id      INT REFERENCES employees(employee_id),
    salary          NUMERIC(12,2) NOT NULL,
    employment_type VARCHAR(20) CHECK (employment_type IN ('full-time','part-time','contract','intern')),
    status          VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','inactive','terminated')),
    created_at      TIMESTAMP DEFAULT NOW()
);

ALTER TABLE departments
    ADD CONSTRAINT fk_dept_head FOREIGN KEY (head_employee_id) REFERENCES employees(employee_id);

CREATE TABLE attendance (
    attendance_id   SERIAL PRIMARY KEY,
    employee_id     INT NOT NULL REFERENCES employees(employee_id),
    work_date       DATE NOT NULL,
    check_in        TIME,
    check_out       TIME,
    hours_worked    NUMERIC(5,2),
    status          VARCHAR(20) DEFAULT 'present' CHECK (status IN ('present','absent','half-day','remote')),
    UNIQUE (employee_id, work_date)
);

CREATE TABLE leave_requests (
    leave_id        SERIAL PRIMARY KEY,
    employee_id     INT NOT NULL REFERENCES employees(employee_id),
    leave_type      VARCHAR(30) CHECK (leave_type IN ('sick','casual','earned','maternity','paternity','unpaid')),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    reason          TEXT,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
    approved_by     INT REFERENCES employees(employee_id),
    applied_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE payroll (
    payroll_id      SERIAL PRIMARY KEY,
    employee_id     INT NOT NULL REFERENCES employees(employee_id),
    pay_period      DATE NOT NULL,              -- first day of month
    basic_salary    NUMERIC(12,2),
    allowances      NUMERIC(12,2) DEFAULT 0,
    deductions      NUMERIC(12,2) DEFAULT 0,
    tax             NUMERIC(12,2) DEFAULT 0,
    net_pay         NUMERIC(12,2),
    paid_on         DATE,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','paid','failed')),
    UNIQUE (employee_id, pay_period)
);

-- ============================================================
--  INVENTORY MODULE
-- ============================================================

CREATE TABLE warehouses (
    warehouse_id    SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    location        VARCHAR(200),
    capacity        INT,
    manager_id      INT REFERENCES employees(employee_id)
);

CREATE TABLE product_categories (
    category_id     SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    parent_id       INT REFERENCES product_categories(category_id),
    description     TEXT
);

CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(50) UNIQUE NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    category_id     INT REFERENCES product_categories(category_id),
    unit_price      NUMERIC(12,2) NOT NULL,
    cost_price      NUMERIC(12,2),
    qty_in_stock    INT DEFAULT 0,
    reorder_level   INT DEFAULT 10,
    warehouse_id    INT REFERENCES warehouses(warehouse_id),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE stock_movements (
    movement_id     SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id),
    movement_type   VARCHAR(20) CHECK (movement_type IN ('purchase','sale','adjustment','transfer','return')),
    quantity        INT NOT NULL,
    reference_id    INT,                        -- order id
    reference_type  VARCHAR(30),               -- 'sales_order' | 'purchase_order'
    moved_at        TIMESTAMP DEFAULT NOW(),
    notes           TEXT
);

-- ============================================================
--  SALES MODULE
-- ============================================================

CREATE TABLE customers (
    customer_id     SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    email           VARCHAR(120),
    phone           VARCHAR(20),
    address         TEXT,
    city            VARCHAR(80),
    state           VARCHAR(80),
    country         VARCHAR(80) DEFAULT 'India',
    credit_limit    NUMERIC(15,2) DEFAULT 50000,
    assigned_rep    INT REFERENCES employees(employee_id),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE sales_orders (
    order_id        SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(customer_id),
    order_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery DATE,
    status          VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending','confirmed','processing','shipped','delivered','cancelled')),
    total_amount    NUMERIC(15,2),
    discount        NUMERIC(5,2) DEFAULT 0,     -- percent
    tax_amount      NUMERIC(12,2) DEFAULT 0,
    created_by      INT REFERENCES employees(employee_id),
    notes           TEXT
);

CREATE TABLE sales_order_items (
    item_id         SERIAL PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES sales_orders(order_id),
    product_id      INT NOT NULL REFERENCES products(product_id),
    quantity        INT NOT NULL,
    unit_price      NUMERIC(12,2) NOT NULL,
    line_total      NUMERIC(15,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE invoices (
    invoice_id      SERIAL PRIMARY KEY,
    order_id        INT REFERENCES sales_orders(order_id),
    customer_id     INT NOT NULL REFERENCES customers(customer_id),
    invoice_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date        DATE,
    amount          NUMERIC(15,2),
    amount_paid     NUMERIC(15,2) DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'unpaid' CHECK (status IN ('unpaid','partial','paid','overdue','cancelled')),
    payment_method  VARCHAR(30)
);

CREATE TABLE invoice_items (
    item_id         SERIAL PRIMARY KEY,
    invoice_id      INT NOT NULL REFERENCES invoices(invoice_id),
    description     VARCHAR(300),
    quantity        INT,
    unit_price      NUMERIC(12,2),
    amount          NUMERIC(15,2)
);

-- ============================================================
--  PROCUREMENT MODULE
-- ============================================================

CREATE TABLE suppliers (
    supplier_id     SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    contact_name    VARCHAR(100),
    email           VARCHAR(120),
    phone           VARCHAR(20),
    address         TEXT,
    city            VARCHAR(80),
    country         VARCHAR(80) DEFAULT 'India',
    payment_terms   INT DEFAULT 30,             -- days
    rating          NUMERIC(3,1) DEFAULT 3.0,
    is_active       BOOLEAN DEFAULT TRUE
);

CREATE TABLE purchase_orders (
    po_id           SERIAL PRIMARY KEY,
    supplier_id     INT NOT NULL REFERENCES suppliers(supplier_id),
    po_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date   DATE,
    status          VARCHAR(30) DEFAULT 'draft' CHECK (status IN ('draft','sent','confirmed','received','cancelled')),
    total_amount    NUMERIC(15,2),
    created_by      INT REFERENCES employees(employee_id),
    notes           TEXT
);

CREATE TABLE purchase_order_items (
    item_id         SERIAL PRIMARY KEY,
    po_id           INT NOT NULL REFERENCES purchase_orders(po_id),
    product_id      INT NOT NULL REFERENCES products(product_id),
    quantity        INT NOT NULL,
    unit_cost       NUMERIC(12,2) NOT NULL,
    line_total      NUMERIC(15,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED
);

-- ============================================================
--  FINANCE MODULE
-- ============================================================

CREATE TABLE accounts (
    account_id      SERIAL PRIMARY KEY,
    account_code    VARCHAR(20) UNIQUE NOT NULL,
    name            VARCHAR(150) NOT NULL,
    account_type    VARCHAR(30) CHECK (account_type IN ('asset','liability','equity','revenue','expense')),
    balance         NUMERIC(18,2) DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE
);

CREATE TABLE journal_entries (
    entry_id        SERIAL PRIMARY KEY,
    entry_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    description     TEXT,
    reference       VARCHAR(100),
    created_by      INT REFERENCES employees(employee_id),
    posted          BOOLEAN DEFAULT FALSE
);

CREATE TABLE journal_lines (
    line_id         SERIAL PRIMARY KEY,
    entry_id        INT NOT NULL REFERENCES journal_entries(entry_id),
    account_id      INT NOT NULL REFERENCES accounts(account_id),
    debit           NUMERIC(15,2) DEFAULT 0,
    credit          NUMERIC(15,2) DEFAULT 0,
    description     TEXT
);

-- ============================================================
--  CRM MODULE
-- ============================================================

CREATE TABLE crm_leads (
    lead_id         SERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    company         VARCHAR(200),
    email           VARCHAR(120),
    phone           VARCHAR(20),
    source          VARCHAR(50),               -- 'website','referral','cold-call', etc.
    status          VARCHAR(30) DEFAULT 'new' CHECK (status IN ('new','contacted','qualified','proposal','won','lost')),
    estimated_value NUMERIC(15,2),
    assigned_to     INT REFERENCES employees(employee_id),
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
--  INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX idx_emp_dept    ON employees(department_id);
CREATE INDEX idx_emp_mgr     ON employees(manager_id);
CREATE INDEX idx_att_emp     ON attendance(employee_id);
CREATE INDEX idx_so_cust     ON sales_orders(customer_id);
CREATE INDEX idx_so_status   ON sales_orders(status);
CREATE INDEX idx_inv_cust    ON invoices(customer_id);
CREATE INDEX idx_inv_status  ON invoices(status);
CREATE INDEX idx_po_supp     ON purchase_orders(supplier_id);
CREATE INDEX idx_prod_cat    ON products(category_id);
CREATE INDEX idx_stock_prod  ON stock_movements(product_id);
CREATE INDEX idx_lead_status ON crm_leads(status);
