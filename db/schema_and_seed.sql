-- ============================================================
--  ERP CHATBOT - FULL DATABASE SCHEMA + SEED DATA
--  PostgreSQL
-- ============================================================

-- ─── DROP IN REVERSE DEP ORDER ───────────────────────────────
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS payroll CASCADE;
DROP TABLE IF EXISTS leave_requests CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS designations CASCADE;

DROP TABLE IF EXISTS invoice_items CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS sales_order_items CASCADE;
DROP TABLE IF EXISTS sales_orders CASCADE;
DROP TABLE IF EXISTS quotation_items CASCADE;
DROP TABLE IF EXISTS quotations CASCADE;

DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS warehouse_locations CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS units_of_measure CASCADE;

DROP TABLE IF EXISTS vendor_contacts CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;
DROP TABLE IF EXISTS customer_contacts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

DROP TABLE IF EXISTS chart_of_accounts CASCADE;
DROP TABLE IF EXISTS journal_entries CASCADE;
DROP TABLE IF EXISTS journal_entry_lines CASCADE;
DROP TABLE IF EXISTS tax_rates CASCADE;
DROP TABLE IF EXISTS currencies CASCADE;

DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS project_tasks CASCADE;
DROP TABLE IF EXISTS project_resources CASCADE;

DROP TABLE IF EXISTS assets CASCADE;
DROP TABLE IF EXISTS asset_categories CASCADE;
DROP TABLE IF EXISTS asset_depreciation CASCADE;

-- ════════════════════════════════════════════════════════════
--  1. HR MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE departments (
    dept_id        SERIAL PRIMARY KEY,
    dept_name      VARCHAR(100) NOT NULL,
    dept_code      VARCHAR(20)  UNIQUE NOT NULL,
    parent_dept_id INT REFERENCES departments(dept_id),
    location       VARCHAR(100),
    budget         NUMERIC(15,2) DEFAULT 0,
    created_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE designations (
    desig_id    SERIAL PRIMARY KEY,
    title       VARCHAR(100) NOT NULL,
    grade       VARCHAR(10),
    min_salary  NUMERIC(12,2),
    max_salary  NUMERIC(12,2)
);

CREATE TABLE employees (
    emp_id          SERIAL PRIMARY KEY,
    emp_code        VARCHAR(20) UNIQUE NOT NULL,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    dept_id         INT REFERENCES departments(dept_id),
    desig_id        INT REFERENCES designations(desig_id),
    manager_id      INT REFERENCES employees(emp_id),
    hire_date       DATE NOT NULL,
    employment_type VARCHAR(20) CHECK (employment_type IN ('Full-Time','Part-Time','Contract','Intern')),
    status          VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active','Inactive','Terminated','On Leave')),
    base_salary     NUMERIC(12,2),
    gender          VARCHAR(10),
    date_of_birth   DATE,
    address         TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE attendance (
    attend_id   SERIAL PRIMARY KEY,
    emp_id      INT NOT NULL REFERENCES employees(emp_id),
    attend_date DATE NOT NULL,
    check_in    TIME,
    check_out   TIME,
    status      VARCHAR(20) DEFAULT 'Present' CHECK (status IN ('Present','Absent','Half Day','Holiday','Leave')),
    work_hours  NUMERIC(4,2),
    UNIQUE(emp_id, attend_date)
);

CREATE TABLE leave_requests (
    leave_id    SERIAL PRIMARY KEY,
    emp_id      INT NOT NULL REFERENCES employees(emp_id),
    leave_type  VARCHAR(30) CHECK (leave_type IN ('Annual','Sick','Maternity','Paternity','Unpaid','Compensatory')),
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    days        INT,
    reason      TEXT,
    status      VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending','Approved','Rejected','Cancelled')),
    approved_by INT REFERENCES employees(emp_id),
    applied_on  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE payroll (
    payroll_id      SERIAL PRIMARY KEY,
    emp_id          INT NOT NULL REFERENCES employees(emp_id),
    pay_period      VARCHAR(20) NOT NULL, -- e.g. '2024-01'
    basic_pay       NUMERIC(12,2),
    allowances      NUMERIC(12,2) DEFAULT 0,
    deductions      NUMERIC(12,2) DEFAULT 0,
    tax_deducted    NUMERIC(12,2) DEFAULT 0,
    net_pay         NUMERIC(12,2),
    payment_date    DATE,
    payment_method  VARCHAR(30),
    status          VARCHAR(20) DEFAULT 'Processed',
    UNIQUE(emp_id, pay_period)
);

-- ════════════════════════════════════════════════════════════
--  2. INVENTORY & PRODUCTS MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE units_of_measure (
    uom_id   SERIAL PRIMARY KEY,
    uom_name VARCHAR(50) NOT NULL,
    uom_code VARCHAR(10) UNIQUE NOT NULL
);

CREATE TABLE product_categories (
    cat_id      SERIAL PRIMARY KEY,
    cat_name    VARCHAR(100) NOT NULL,
    parent_cat  INT REFERENCES product_categories(cat_id),
    description TEXT
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    sku           VARCHAR(50) UNIQUE NOT NULL,
    product_name  VARCHAR(200) NOT NULL,
    cat_id        INT REFERENCES product_categories(cat_id),
    uom_id        INT REFERENCES units_of_measure(uom_id),
    description   TEXT,
    unit_cost     NUMERIC(12,2),
    unit_price    NUMERIC(12,2),
    reorder_level INT DEFAULT 0,
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE warehouse_locations (
    loc_id      SERIAL PRIMARY KEY,
    loc_code    VARCHAR(30) UNIQUE NOT NULL,
    loc_name    VARCHAR(100),
    address     TEXT,
    city        VARCHAR(50),
    country     VARCHAR(50)
);

CREATE TABLE inventory (
    inv_id      SERIAL PRIMARY KEY,
    product_id  INT NOT NULL REFERENCES products(product_id),
    loc_id      INT NOT NULL REFERENCES warehouse_locations(loc_id),
    qty_on_hand NUMERIC(12,2) DEFAULT 0,
    qty_reserved NUMERIC(12,2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT NOW(),
    UNIQUE(product_id, loc_id)
);

CREATE TABLE stock_movements (
    move_id      SERIAL PRIMARY KEY,
    product_id   INT NOT NULL REFERENCES products(product_id),
    loc_id       INT REFERENCES warehouse_locations(loc_id),
    move_type    VARCHAR(30) CHECK (move_type IN ('IN','OUT','TRANSFER','ADJUSTMENT')),
    quantity     NUMERIC(12,2),
    reference    VARCHAR(100),
    notes        TEXT,
    moved_at     TIMESTAMP DEFAULT NOW(),
    moved_by     INT REFERENCES employees(emp_id)
);

-- ════════════════════════════════════════════════════════════
--  3. CRM - CUSTOMERS & VENDORS
-- ════════════════════════════════════════════════════════════

CREATE TABLE customers (
    cust_id        SERIAL PRIMARY KEY,
    cust_code      VARCHAR(30) UNIQUE NOT NULL,
    company_name   VARCHAR(200) NOT NULL,
    email          VARCHAR(100),
    phone          VARCHAR(30),
    billing_address TEXT,
    city           VARCHAR(50),
    country        VARCHAR(50),
    credit_limit   NUMERIC(15,2) DEFAULT 0,
    payment_terms  VARCHAR(50),
    status         VARCHAR(20) DEFAULT 'Active',
    created_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE customer_contacts (
    contact_id  SERIAL PRIMARY KEY,
    cust_id     INT NOT NULL REFERENCES customers(cust_id),
    name        VARCHAR(100),
    email       VARCHAR(100),
    phone       VARCHAR(30),
    designation VARCHAR(100),
    is_primary  BOOLEAN DEFAULT FALSE
);

CREATE TABLE vendors (
    vendor_id      SERIAL PRIMARY KEY,
    vendor_code    VARCHAR(30) UNIQUE NOT NULL,
    company_name   VARCHAR(200) NOT NULL,
    email          VARCHAR(100),
    phone          VARCHAR(30),
    address        TEXT,
    city           VARCHAR(50),
    country        VARCHAR(50),
    payment_terms  VARCHAR(50),
    tax_number     VARCHAR(50),
    status         VARCHAR(20) DEFAULT 'Active',
    created_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE vendor_contacts (
    contact_id  SERIAL PRIMARY KEY,
    vendor_id   INT NOT NULL REFERENCES vendors(vendor_id),
    name        VARCHAR(100),
    email       VARCHAR(100),
    phone       VARCHAR(30),
    is_primary  BOOLEAN DEFAULT FALSE
);

-- ════════════════════════════════════════════════════════════
--  4. SALES MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE quotations (
    quote_id    SERIAL PRIMARY KEY,
    quote_no    VARCHAR(30) UNIQUE NOT NULL,
    cust_id     INT NOT NULL REFERENCES customers(cust_id),
    quote_date  DATE NOT NULL,
    valid_until DATE,
    status      VARCHAR(30) DEFAULT 'Draft' CHECK (status IN ('Draft','Sent','Accepted','Rejected','Expired')),
    subtotal    NUMERIC(15,2) DEFAULT 0,
    tax_amount  NUMERIC(15,2) DEFAULT 0,
    total       NUMERIC(15,2) DEFAULT 0,
    notes       TEXT,
    created_by  INT REFERENCES employees(emp_id)
);

CREATE TABLE quotation_items (
    item_id     SERIAL PRIMARY KEY,
    quote_id    INT NOT NULL REFERENCES quotations(quote_id),
    product_id  INT NOT NULL REFERENCES products(product_id),
    qty         NUMERIC(12,2),
    unit_price  NUMERIC(12,2),
    discount    NUMERIC(5,2) DEFAULT 0,
    line_total  NUMERIC(15,2)
);

CREATE TABLE sales_orders (
    so_id       SERIAL PRIMARY KEY,
    so_no       VARCHAR(30) UNIQUE NOT NULL,
    cust_id     INT NOT NULL REFERENCES customers(cust_id),
    quote_id    INT REFERENCES quotations(quote_id),
    order_date  DATE NOT NULL,
    delivery_date DATE,
    status      VARCHAR(30) DEFAULT 'Pending' CHECK (status IN ('Pending','Confirmed','Processing','Shipped','Delivered','Cancelled')),
    subtotal    NUMERIC(15,2) DEFAULT 0,
    tax_amount  NUMERIC(15,2) DEFAULT 0,
    total       NUMERIC(15,2) DEFAULT 0,
    shipping_address TEXT,
    notes       TEXT,
    created_by  INT REFERENCES employees(emp_id)
);

CREATE TABLE sales_order_items (
    item_id     SERIAL PRIMARY KEY,
    so_id       INT NOT NULL REFERENCES sales_orders(so_id),
    product_id  INT NOT NULL REFERENCES products(product_id),
    qty         NUMERIC(12,2),
    unit_price  NUMERIC(12,2),
    discount    NUMERIC(5,2) DEFAULT 0,
    line_total  NUMERIC(15,2)
);

-- ════════════════════════════════════════════════════════════
--  5. PURCHASE MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE purchase_orders (
    po_id       SERIAL PRIMARY KEY,
    po_no       VARCHAR(30) UNIQUE NOT NULL,
    vendor_id   INT NOT NULL REFERENCES vendors(vendor_id),
    order_date  DATE NOT NULL,
    expected_date DATE,
    status      VARCHAR(30) DEFAULT 'Draft' CHECK (status IN ('Draft','Sent','Partial','Received','Cancelled')),
    subtotal    NUMERIC(15,2) DEFAULT 0,
    tax_amount  NUMERIC(15,2) DEFAULT 0,
    total       NUMERIC(15,2) DEFAULT 0,
    notes       TEXT,
    created_by  INT REFERENCES employees(emp_id)
);

CREATE TABLE purchase_order_items (
    item_id     SERIAL PRIMARY KEY,
    po_id       INT NOT NULL REFERENCES purchase_orders(po_id),
    product_id  INT NOT NULL REFERENCES products(product_id),
    qty_ordered NUMERIC(12,2),
    qty_received NUMERIC(12,2) DEFAULT 0,
    unit_cost   NUMERIC(12,2),
    line_total  NUMERIC(15,2)
);

-- ════════════════════════════════════════════════════════════
--  6. FINANCE MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE currencies (
    currency_id   SERIAL PRIMARY KEY,
    code          VARCHAR(5) UNIQUE NOT NULL,
    name          VARCHAR(50),
    exchange_rate NUMERIC(10,4) DEFAULT 1.0
);

CREATE TABLE tax_rates (
    tax_id    SERIAL PRIMARY KEY,
    tax_name  VARCHAR(50) NOT NULL,
    rate      NUMERIC(5,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE chart_of_accounts (
    account_id   SERIAL PRIMARY KEY,
    account_code VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(30) CHECK (account_type IN ('Asset','Liability','Equity','Revenue','Expense')),
    parent_id    INT REFERENCES chart_of_accounts(account_id),
    is_active    BOOLEAN DEFAULT TRUE
);

CREATE TABLE journal_entries (
    je_id        SERIAL PRIMARY KEY,
    je_no        VARCHAR(30) UNIQUE NOT NULL,
    entry_date   DATE NOT NULL,
    description  TEXT,
    reference    VARCHAR(100),
    status       VARCHAR(20) DEFAULT 'Posted',
    created_by   INT REFERENCES employees(emp_id),
    created_at   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE journal_entry_lines (
    line_id     SERIAL PRIMARY KEY,
    je_id       INT NOT NULL REFERENCES journal_entries(je_id),
    account_id  INT NOT NULL REFERENCES chart_of_accounts(account_id),
    debit       NUMERIC(15,2) DEFAULT 0,
    credit      NUMERIC(15,2) DEFAULT 0,
    description TEXT
);

CREATE TABLE invoices (
    inv_id      SERIAL PRIMARY KEY,
    inv_no      VARCHAR(30) UNIQUE NOT NULL,
    cust_id     INT NOT NULL REFERENCES customers(cust_id),
    so_id       INT REFERENCES sales_orders(so_id),
    inv_date    DATE NOT NULL,
    due_date    DATE,
    status      VARCHAR(30) DEFAULT 'Unpaid' CHECK (status IN ('Draft','Unpaid','Partial','Paid','Overdue','Cancelled')),
    subtotal    NUMERIC(15,2) DEFAULT 0,
    tax_amount  NUMERIC(15,2) DEFAULT 0,
    total       NUMERIC(15,2) DEFAULT 0,
    paid_amount NUMERIC(15,2) DEFAULT 0,
    notes       TEXT
);

CREATE TABLE invoice_items (
    item_id    SERIAL PRIMARY KEY,
    inv_id     INT NOT NULL REFERENCES invoices(inv_id),
    product_id INT REFERENCES products(product_id),
    description TEXT,
    qty        NUMERIC(12,2),
    unit_price NUMERIC(12,2),
    line_total NUMERIC(15,2)
);

-- ════════════════════════════════════════════════════════════
--  7. PROJECT MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE projects (
    proj_id     SERIAL PRIMARY KEY,
    proj_code   VARCHAR(30) UNIQUE NOT NULL,
    proj_name   VARCHAR(200) NOT NULL,
    cust_id     INT REFERENCES customers(cust_id),
    start_date  DATE,
    end_date    DATE,
    budget      NUMERIC(15,2),
    status      VARCHAR(30) DEFAULT 'Planning' CHECK (status IN ('Planning','Active','On Hold','Completed','Cancelled')),
    manager_id  INT REFERENCES employees(emp_id),
    description TEXT
);

CREATE TABLE project_tasks (
    task_id     SERIAL PRIMARY KEY,
    proj_id     INT NOT NULL REFERENCES projects(proj_id),
    task_name   VARCHAR(200) NOT NULL,
    assigned_to INT REFERENCES employees(emp_id),
    start_date  DATE,
    due_date    DATE,
    status      VARCHAR(30) DEFAULT 'Todo' CHECK (status IN ('Todo','In Progress','Review','Done','Blocked')),
    priority    VARCHAR(20) DEFAULT 'Medium' CHECK (priority IN ('Low','Medium','High','Critical')),
    estimated_hrs NUMERIC(6,2),
    actual_hrs  NUMERIC(6,2)
);

CREATE TABLE project_resources (
    res_id    SERIAL PRIMARY KEY,
    proj_id   INT NOT NULL REFERENCES projects(proj_id),
    emp_id    INT NOT NULL REFERENCES employees(emp_id),
    role      VARCHAR(100),
    allocation_pct NUMERIC(5,2) DEFAULT 100
);

-- ════════════════════════════════════════════════════════════
--  8. ASSET MANAGEMENT MODULE
-- ════════════════════════════════════════════════════════════

CREATE TABLE asset_categories (
    cat_id    SERIAL PRIMARY KEY,
    cat_name  VARCHAR(100) NOT NULL,
    useful_life_years INT
);

CREATE TABLE assets (
    asset_id      SERIAL PRIMARY KEY,
    asset_code    VARCHAR(30) UNIQUE NOT NULL,
    asset_name    VARCHAR(200) NOT NULL,
    cat_id        INT REFERENCES asset_categories(cat_id),
    purchase_date DATE,
    purchase_cost NUMERIC(15,2),
    current_value NUMERIC(15,2),
    location      VARCHAR(100),
    assigned_to   INT REFERENCES employees(emp_id),
    status        VARCHAR(30) DEFAULT 'Active' CHECK (status IN ('Active','In Maintenance','Disposed','Lost')),
    serial_no     VARCHAR(100)
);

CREATE TABLE asset_depreciation (
    dep_id    SERIAL PRIMARY KEY,
    asset_id  INT NOT NULL REFERENCES assets(asset_id),
    dep_date  DATE NOT NULL,
    dep_amount NUMERIC(15,2),
    book_value NUMERIC(15,2),
    method     VARCHAR(30)
);

-- ════════════════════════════════════════════════════════════
--  9. AUDIT LOG
-- ════════════════════════════════════════════════════════════

CREATE TABLE audit_logs (
    log_id      SERIAL PRIMARY KEY,
    table_name  VARCHAR(100),
    record_id   INT,
    action      VARCHAR(20),
    changed_by  INT REFERENCES employees(emp_id),
    changed_at  TIMESTAMP DEFAULT NOW(),
    old_data    JSONB,
    new_data    JSONB
);

-- ════════════════════════════════════════════════════════════
--  SEED DATA
-- ════════════════════════════════════════════════════════════

INSERT INTO departments (dept_name, dept_code, location, budget) VALUES
('Executive','EXEC','HQ',5000000),
('Human Resources','HR','HQ',800000),
('Information Technology','IT','HQ',1500000),
('Finance & Accounting','FIN','HQ',1200000),
('Sales & Marketing','SALES','Mumbai',2000000),
('Operations','OPS','Pune',1800000),
('Procurement','PROC','HQ',900000),
('Research & Development','RND','Bangalore',3000000),
('Customer Support','CS','Mumbai',600000),
('Warehouse & Logistics','WH','Pune',700000);

INSERT INTO designations (title, grade, min_salary, max_salary) VALUES
('CEO','L10',500000,1000000),
('CTO','L9',400000,800000),
('CFO','L9',400000,800000),
('VP Sales','L8',300000,600000),
('Senior Manager','L7',200000,400000),
('Manager','L6',150000,300000),
('Senior Engineer','L5',100000,200000),
('Engineer','L4',70000,120000),
('Analyst','L3',50000,90000),
('Associate','L2',35000,60000),
('Intern','L1',15000,25000);

INSERT INTO employees (emp_code,first_name,last_name,email,phone,dept_id,desig_id,hire_date,employment_type,status,base_salary,gender) VALUES
('EMP001','Rajesh','Sharma','rajesh.sharma@erpcorp.com','9876543210',1,1,'2018-01-15','Full-Time','Active',750000,'Male'),
('EMP002','Priya','Mehta','priya.mehta@erpcorp.com','9876543211',2,5,'2019-03-01','Full-Time','Active',280000,'Female'),
('EMP003','Aakash','Verma','aakash.verma@erpcorp.com','9876543212',3,2,'2018-06-15','Full-Time','Active',550000,'Male'),
('EMP004','Sneha','Patil','sneha.patil@erpcorp.com','9876543213',4,3,'2019-08-01','Full-Time','Active',520000,'Female'),
('EMP005','Vikram','Joshi','vikram.joshi@erpcorp.com','9876543214',5,4,'2020-02-15','Full-Time','Active',380000,'Male'),
('EMP006','Ananya','Desai','ananya.desai@erpcorp.com','9876543215',3,7,'2020-07-01','Full-Time','Active',140000,'Female'),
('EMP007','Rohan','Kumar','rohan.kumar@erpcorp.com','9876543216',3,8,'2021-01-10','Full-Time','Active',90000,'Male'),
('EMP008','Kavya','Nair','kavya.nair@erpcorp.com','9876543217',5,9,'2021-04-01','Full-Time','Active',65000,'Female'),
('EMP009','Arjun','Singh','arjun.singh@erpcorp.com','9876543218',6,6,'2019-11-01','Full-Time','Active',210000,'Male'),
('EMP010','Pooja','Iyer','pooja.iyer@erpcorp.com','9876543219',4,9,'2022-01-15','Full-Time','Active',60000,'Female'),
('EMP011','Nikhil','Rao','nikhil.rao@erpcorp.com','9876543220',7,6,'2020-05-01','Full-Time','Active',180000,'Male'),
('EMP012','Ritu','Gupta','ritu.gupta@erpcorp.com','9876543221',2,9,'2022-06-01','Full-Time','Active',58000,'Female'),
('EMP013','Siddharth','Pandey','siddharth.pandey@erpcorp.com','9876543222',8,7,'2021-08-01','Full-Time','Active',130000,'Male'),
('EMP014','Meera','Bhat','meera.bhat@erpcorp.com','9876543223',9,10,'2023-01-02','Full-Time','Active',42000,'Female'),
('EMP015','Karan','Tiwari','karan.tiwari@erpcorp.com','9876543224',5,8,'2022-03-15','Full-Time','Active',85000,'Male');

-- Update manager references
UPDATE employees SET manager_id=1 WHERE emp_id IN (2,3,4,5,9,11);
UPDATE employees SET manager_id=3 WHERE emp_id IN (6,7,13);
UPDATE employees SET manager_id=5 WHERE emp_id IN (8,15);
UPDATE employees SET manager_id=4 WHERE emp_id=10;
UPDATE employees SET manager_id=2 WHERE emp_id=12;
UPDATE employees SET manager_id=11 WHERE emp_id=14;

INSERT INTO units_of_measure (uom_name, uom_code) VALUES
('Each','EA'),('Kilogram','KG'),('Litre','LTR'),('Box','BOX'),('Meter','MTR'),('Piece','PC');

INSERT INTO product_categories (cat_name, description) VALUES
('Electronics','Electronic components and devices'),
('Office Supplies','Stationery and office consumables'),
('Raw Materials','Manufacturing raw materials'),
('Finished Goods','Ready to sell products'),
('IT Equipment','Computers, servers, networking'),
('Software Licenses','Software and SaaS subscriptions');

INSERT INTO products (sku,product_name,cat_id,uom_id,unit_cost,unit_price,reorder_level) VALUES
('SKU-LAPTOP-001','Dell Latitude 5540 Laptop',5,1,65000,85000,5),
('SKU-LAPTOP-002','HP EliteBook 840 G10',5,1,70000,92000,5),
('SKU-SRV-001','Dell PowerEdge R750 Server',5,1,350000,450000,2),
('SKU-MON-001','LG 27" 4K Monitor',5,1,22000,30000,10),
('SKU-SW-ERP','SAP ERP License (Annual)',6,1,500000,700000,0),
('SKU-SW-OFFICE','MS Office 365 Business',6,1,8000,12000,0),
('SKU-PAPER-A4','A4 Paper Ream 500 sheets',2,4,200,350,50),
('SKU-PEN-001','Ball Point Pen (Box of 10)',2,4,50,100,100),
('SKU-STL-001','Steel Rod 6mm (per meter)',3,5,85,120,200),
('SKU-CEMENT-001','OPC Cement 50kg bag',3,1,400,550,500),
('SKU-CABLE-001','Cat6 LAN Cable (per meter)',1,5,25,45,300),
('SKU-SWITCH-001','Cisco 24-port Network Switch',5,1,45000,62000,3),
('SKU-CHAIR-001','Ergonomic Office Chair',2,1,8000,14000,20),
('SKU-DESK-001','Executive Office Desk',2,1,15000,25000,10),
('SKU-PHONE-001','IP Desk Phone Polycom',1,1,6000,9500,15);

INSERT INTO warehouse_locations (loc_code,loc_name,address,city,country) VALUES
('WH-PUNE-01','Pune Main Warehouse','MIDC Chakan, Pune','Pune','India'),
('WH-MUM-01','Mumbai Distribution Center','BKC, Mumbai','Mumbai','India'),
('WH-BLR-01','Bangalore Tech Hub','Whitefield, Bangalore','Bangalore','India');

INSERT INTO inventory (product_id,loc_id,qty_on_hand,qty_reserved) VALUES
(1,1,25,5),(2,1,18,3),(3,1,5,1),(4,1,40,8),(5,1,0,0),
(6,1,50,10),(7,2,200,30),(8,2,500,50),(9,1,1000,100),
(10,1,800,200),(11,1,2000,300),(12,1,8,2),(13,2,60,15),
(14,2,30,5),(15,2,25,3);

INSERT INTO customers (cust_code,company_name,email,phone,city,country,credit_limit,payment_terms) VALUES
('CUST-001','TechSolutions Pvt Ltd','accounts@techsolutions.in','022-45678901','Mumbai','India',5000000,'Net 30'),
('CUST-002','BuildRight Constructions','finance@buildright.com','020-87654321','Pune','India',10000000,'Net 45'),
('CUST-003','InfoSystems Ltd','ap@infosystems.co.in','080-23456789','Bangalore','India',3000000,'Net 30'),
('CUST-004','Sunrise Manufacturing','purchase@sunrisemfg.in','0240-234567','Aurangabad','India',7500000,'Net 60'),
('CUST-005','Global Traders Co','info@globaltraders.com','011-45678901','Delhi','India',2000000,'Net 15'),
('CUST-006','Nexus Retail Chain','finance@nexusretail.in','044-98765432','Chennai','India',8000000,'Net 30'),
('CUST-007','DataMinds Analytics','billing@dataminds.ai','080-11223344','Bangalore','India',1500000,'Net 30'),
('CUST-008','Horizon Exports','accounts@horizonexp.com','022-99887766','Mumbai','India',4000000,'Net 45');

INSERT INTO vendors (vendor_code,company_name,email,phone,city,country,payment_terms) VALUES
('VND-001','Dell Technologies India','sales@dell.co.in','1800-425-4008','Bangalore','India','Net 45'),
('VND-002','HP India Pvt Ltd','enterprise@hp.com','1800-425-4999','Mumbai','India','Net 30'),
('VND-003','Cisco Systems India','partners@cisco.in','080-22088400','Bangalore','India','Net 45'),
('VND-004','Tata Steel','procurement@tatasteel.com','022-66581234','Mumbai','India','Net 30'),
('VND-005','UltraTech Cement','sales@ultratech.com','022-48582000','Mumbai','India','Net 15'),
('VND-006','Staples India','b2b@staples.in','1800-180-8282','Pune','India','Net 30'),
('VND-007','Polycom India','enterprise@polycom.in','080-41234567','Bangalore','India','Net 45'),
('VND-008','Microsoft India','enterprise@microsoft.com','1800-102-1100','Hyderabad','India','Net 30');

INSERT INTO quotations (quote_no,cust_id,quote_date,valid_until,status,subtotal,tax_amount,total,created_by) VALUES
('QT-2024-001',1,'2024-01-05','2024-01-20','Accepted',170000,30600,200600,5),
('QT-2024-002',2,'2024-01-10','2024-01-25','Accepted',450000,81000,531000,5),
('QT-2024-003',3,'2024-02-01','2024-02-16','Accepted',84000,15120,99120,8),
('QT-2024-004',4,'2024-02-15','2024-03-01','Sent',230000,41400,271400,5),
('QT-2024-005',5,'2024-03-01','2024-03-16','Expired',42000,7560,49560,15);

INSERT INTO sales_orders (so_no,cust_id,quote_id,order_date,delivery_date,status,subtotal,tax_amount,total,created_by) VALUES
('SO-2024-001',1,1,'2024-01-22','2024-02-05','Delivered',170000,30600,200600,5),
('SO-2024-002',2,2,'2024-01-28','2024-02-20','Shipped',450000,81000,531000,5),
('SO-2024-003',3,3,'2024-02-10','2024-02-25','Delivered',84000,15120,99120,8),
('SO-2024-004',4,NULL,'2024-03-01','2024-03-20','Processing',150000,27000,177000,5),
('SO-2024-005',6,NULL,'2024-03-10','2024-03-25','Confirmed',320000,57600,377600,15),
('SO-2024-006',7,NULL,'2024-03-15','2024-04-01','Pending',90000,16200,106200,8),
('SO-2024-007',8,NULL,'2024-03-18','2024-04-05','Pending',260000,46800,306800,5);

INSERT INTO sales_order_items (so_id,product_id,qty,unit_price,discount,line_total) VALUES
(1,1,2,85000,5,161500),(1,4,2,30000,0,60000),
(2,3,1,450000,0,450000),
(3,6,10,8400,0,84000),
(4,9,500,120,0,60000),(4,10,200,450,0,90000),
(5,1,3,85000,5,241500),(5,2,1,92000,0,92000),
(6,13,5,14000,2,68600),(6,14,2,25000,5,47500),
(7,12,2,62000,0,124000),(7,15,10,9500,5,90250);

INSERT INTO purchase_orders (po_no,vendor_id,order_date,expected_date,status,subtotal,tax_amount,total,created_by) VALUES
('PO-2024-001',1,'2024-01-10','2024-01-25','Received',260000,46800,306800,11),
('PO-2024-002',2,'2024-01-15','2024-02-01','Received',210000,37800,247800,11),
('PO-2024-003',4,'2024-02-01','2024-02-15','Received',85000,15300,100300,11),
('PO-2024-004',5,'2024-02-10','2024-02-20','Received',200000,36000,236000,11),
('PO-2024-005',6,'2024-03-01','2024-03-10','Partial',15000,2700,17700,11),
('PO-2024-006',3,'2024-03-05','2024-03-20','Sent',270000,48600,318600,11);

INSERT INTO purchase_order_items (po_id,product_id,qty_ordered,qty_received,unit_cost,line_total) VALUES
(1,1,4,4,65000,260000),
(2,2,3,3,70000,210000),
(3,9,1000,1000,85,85000),
(4,10,500,500,400,200000),
(5,7,50,30,200,10000),(5,8,100,100,50,5000),
(6,12,4,0,45000,180000),(6,15,10,0,6000,60000);

INSERT INTO currencies (code,name,exchange_rate) VALUES
('INR','Indian Rupee',1.0),('USD','US Dollar',83.5),('EUR','Euro',90.2),('GBP','British Pound',105.3);

INSERT INTO tax_rates (tax_name,rate) VALUES
('GST 18%',18.0),('GST 12%',12.0),('GST 5%',5.0),('GST 28%',28.0),('TDS 10%',10.0);

INSERT INTO chart_of_accounts (account_code,account_name,account_type) VALUES
('1001','Cash & Bank','Asset'),
('1002','Accounts Receivable','Asset'),
('1003','Inventory','Asset'),
('1004','Fixed Assets','Asset'),
('2001','Accounts Payable','Liability'),
('2002','GST Payable','Liability'),
('2003','Short-Term Loans','Liability'),
('3001','Share Capital','Equity'),
('3002','Retained Earnings','Equity'),
('4001','Product Sales Revenue','Revenue'),
('4002','Service Revenue','Revenue'),
('5001','Cost of Goods Sold','Expense'),
('5002','Salaries & Wages','Expense'),
('5003','Rent & Utilities','Expense'),
('5004','Marketing & Advertising','Expense'),
('5005','Depreciation','Expense');

INSERT INTO invoices (inv_no,cust_id,so_id,inv_date,due_date,status,subtotal,tax_amount,total,paid_amount) VALUES
('INV-2024-001',1,1,'2024-02-06','2024-03-07','Paid',170000,30600,200600,200600),
('INV-2024-002',2,2,'2024-02-22','2024-04-07','Partial',450000,81000,531000,265500),
('INV-2024-003',3,3,'2024-02-26','2024-03-27','Paid',84000,15120,99120,99120),
('INV-2024-004',4,4,'2024-03-22','2024-05-21','Unpaid',150000,27000,177000,0),
('INV-2024-005',6,5,'2024-03-26','2024-04-25','Unpaid',320000,57600,377600,0);

INSERT INTO projects (proj_code,proj_name,cust_id,start_date,end_date,budget,status,manager_id) VALUES
('PROJ-001','ERP Implementation Phase 1',1,'2024-01-01','2024-06-30',2000000,'Active',9),
('PROJ-002','Data Center Upgrade',3,'2024-02-01','2024-05-31',1500000,'Active',3),
('PROJ-003','Mobile App Development',7,'2024-03-01','2024-08-31',800000,'Planning',13),
('PROJ-004','Warehouse Automation',2,'2023-10-01','2024-03-31',3000000,'Completed',9);

INSERT INTO project_tasks (proj_id,task_name,assigned_to,start_date,due_date,status,priority,estimated_hrs,actual_hrs) VALUES
(1,'Requirements Gathering',6,'2024-01-01','2024-01-15','Done','High',40,38),
(1,'System Design',6,'2024-01-16','2024-02-15','Done','High',80,85),
(1,'Module Development',7,'2024-02-16','2024-05-15','In Progress','High',300,180),
(1,'Testing & QA',7,'2024-05-16','2024-06-15','Todo','High',100,0),
(2,'Infrastructure Assessment',6,'2024-02-01','2024-02-28','Done','High',60,55),
(2,'Hardware Procurement',11,'2024-03-01','2024-03-31','In Progress','High',40,20),
(3,'UI/UX Design',13,'2024-03-01','2024-04-30','In Progress','Medium',120,40),
(4,'Final Handover',9,'2024-03-20','2024-03-31','Done','Low',20,22);

INSERT INTO asset_categories (cat_name, useful_life_years) VALUES
('Computers & Laptops',3),('Servers',5),('Networking Equipment',5),
('Furniture',10),('Vehicles',6),('Office Equipment',5);

INSERT INTO assets (asset_code,asset_name,cat_id,purchase_date,purchase_cost,current_value,location,assigned_to,status,serial_no) VALUES
('AST-001','Dell Latitude 5540 - EMP001',1,'2022-06-01',65000,43333,'HQ Office',1,'Active','DLL5540-001'),
('AST-002','Dell PowerEdge Server - DC',2,'2021-01-15',350000,210000,'Server Room',3,'Active','DPWR-2021-001'),
('AST-003','Cisco Switch - Floor 2',3,'2020-08-01',45000,18000,'Network Room',3,'Active','CSC24P-001'),
('AST-004','Executive Desk - CEO',4,'2019-01-01',25000,17500,'HQ Office',1,'Active','DESK-EXC-001'),
('AST-005','Toyota Innova - Company Car',5,'2021-06-01',1600000,960000,'Parking',1,'Active','MH14AB1234');

INSERT INTO payroll (emp_id,pay_period,basic_pay,allowances,deductions,tax_deducted,net_pay,payment_date,payment_method,status) VALUES
(1,'2024-01',62500,15000,5000,12000,60500,'2024-01-31','Bank Transfer','Processed'),
(2,'2024-01',23333,5000,1000,3500,23833,'2024-01-31','Bank Transfer','Processed'),
(3,'2024-01',45833,10000,3000,7500,45333,'2024-01-31','Bank Transfer','Processed'),
(4,'2024-01',43333,10000,3000,7000,43333,'2024-01-31','Bank Transfer','Processed'),
(5,'2024-01',31667,8000,2000,5000,32667,'2024-01-31','Bank Transfer','Processed'),
(6,'2024-01',11667,3000,500,1200,12967,'2024-01-31','Bank Transfer','Processed'),
(7,'2024-01',7500,2000,300,700,8500,'2024-01-31','Bank Transfer','Processed'),
(8,'2024-01',5417,1500,200,500,6217,'2024-01-31','Bank Transfer','Processed'),
(1,'2024-02',62500,15000,5000,12000,60500,'2024-02-29','Bank Transfer','Processed'),
(2,'2024-02',23333,5000,1000,3500,23833,'2024-02-29','Bank Transfer','Processed'),
(3,'2024-02',45833,10000,3000,7500,45333,'2024-02-29','Bank Transfer','Processed');

INSERT INTO leave_requests (emp_id,leave_type,start_date,end_date,days,reason,status,approved_by) VALUES
(7,'Annual','2024-01-20','2024-01-22',3,'Family vacation','Approved',3),
(8,'Sick','2024-02-05','2024-02-06',2,'Fever','Approved',5),
(12,'Annual','2024-02-15','2024-02-19',5,'Personal work','Approved',2),
(14,'Annual','2024-03-01','2024-03-03',3,'Festival','Pending',NULL),
(6,'Sick','2024-03-10','2024-03-10',1,'Doctor visit','Approved',3);

-- ════════════════════════════════════════════════════════════
--  USEFUL VIEWS FOR REPORTING
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW v_employee_summary AS
SELECT e.emp_id, e.emp_code,
       e.first_name || ' ' || e.last_name AS full_name,
       d.dept_name, des.title AS designation,
       e.employment_type, e.status, e.base_salary, e.hire_date,
       m.first_name || ' ' || m.last_name AS manager_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN designations des ON e.desig_id = des.desig_id
LEFT JOIN employees m ON e.manager_id = m.emp_id;

CREATE OR REPLACE VIEW v_inventory_status AS
SELECT p.sku, p.product_name, pc.cat_name AS category,
       w.loc_name AS warehouse,
       i.qty_on_hand, i.qty_reserved,
       (i.qty_on_hand - i.qty_reserved) AS qty_available,
       p.reorder_level,
       CASE WHEN (i.qty_on_hand - i.qty_reserved) <= p.reorder_level
            THEN 'REORDER NEEDED' ELSE 'OK' END AS stock_status,
       p.unit_price
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN product_categories pc ON p.cat_id = pc.cat_id
JOIN warehouse_locations w ON i.loc_id = w.loc_id;

CREATE OR REPLACE VIEW v_sales_summary AS
SELECT so.so_no, c.company_name AS customer,
       so.order_date, so.delivery_date, so.status,
       so.total, e.first_name || ' ' || e.last_name AS sales_rep
FROM sales_orders so
JOIN customers c ON so.cust_id = c.cust_id
LEFT JOIN employees e ON so.created_by = e.emp_id;

CREATE OR REPLACE VIEW v_invoice_aging AS
SELECT i.inv_no, c.company_name AS customer,
       i.inv_date, i.due_date,
       CURRENT_DATE - i.due_date AS days_overdue,
       i.total, i.paid_amount,
       i.total - i.paid_amount AS balance_due,
       i.status
FROM invoices i
JOIN customers c ON i.cust_id = c.cust_id
WHERE i.status NOT IN ('Paid','Cancelled');

CREATE OR REPLACE VIEW v_department_headcount AS
SELECT d.dept_name, d.dept_code,
       COUNT(e.emp_id) AS headcount,
       SUM(e.base_salary) AS total_salary_cost,
       AVG(e.base_salary) AS avg_salary
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id AND e.status = 'Active'
GROUP BY d.dept_id, d.dept_name, d.dept_code;
