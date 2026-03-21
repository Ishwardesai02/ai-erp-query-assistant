-- ============================================================
--  ERP SEED DATA
-- ============================================================

-- DEPARTMENTS (insert first, no head_employee_id yet)
INSERT INTO departments (name, location, budget) VALUES
('Engineering',       'Building A, Floor 3', 5000000),
('Human Resources',   'Building A, Floor 1', 1200000),
('Sales',             'Building B, Floor 2', 3000000),
('Finance',           'Building A, Floor 2', 2000000),
('Operations',        'Building C, Floor 1', 2500000),
('Marketing',         'Building B, Floor 1', 1800000),
('Procurement',       'Building C, Floor 2', 1500000),
('Customer Support',  'Building B, Floor 3', 900000);

-- EMPLOYEES
INSERT INTO employees (first_name, last_name, email, phone, hire_date, job_title, department_id, manager_id, salary, employment_type, status) VALUES
-- HR
('Priya',    'Sharma',    'priya.sharma@erp.com',    '9876543210', '2019-03-15', 'HR Manager',             2, NULL,  95000, 'full-time', 'active'),
('Rohan',    'Mehta',     'rohan.mehta@erp.com',     '9876543211', '2021-06-01', 'HR Executive',           2, 1,     55000, 'full-time', 'active'),
-- Engineering
('Aarav',    'Patel',     'aarav.patel@erp.com',     '9876543212', '2018-01-10', 'Engineering Lead',       1, NULL,  145000,'full-time', 'active'),
('Sneha',    'Kulkarni',  'sneha.kulkarni@erp.com',  '9876543213', '2020-07-15', 'Senior Developer',       1, 3,     120000,'full-time', 'active'),
('Kunal',    'Joshi',     'kunal.joshi@erp.com',     '9876543214', '2022-03-01', 'Junior Developer',       1, 3,     70000, 'full-time', 'active'),
('Meera',    'Desai',     'meera.desai@erp.com',     '9876543215', '2023-08-01', 'Intern Developer',       1, 4,     25000, 'intern',    'active'),
-- Sales
('Vikram',   'Singh',     'vikram.singh@erp.com',    '9876543216', '2017-11-20', 'Sales Manager',          3, NULL,  110000,'full-time', 'active'),
('Ananya',   'Iyer',      'ananya.iyer@erp.com',     '9876543217', '2021-02-14', 'Sales Executive',        3, 7,     65000, 'full-time', 'active'),
('Ravi',     'Nair',      'ravi.nair@erp.com',       '9876543218', '2022-09-05', 'Sales Executive',        3, 7,     60000, 'full-time', 'active'),
-- Finance
('Deepa',    'Rao',       'deepa.rao@erp.com',       '9876543219', '2016-05-01', 'Finance Manager',        4, NULL,  130000,'full-time', 'active'),
('Amit',     'Verma',     'amit.verma@erp.com',      '9876543220', '2020-10-10', 'Accountant',             4, 10,    72000, 'full-time', 'active'),
-- Operations
('Sanjay',   'Gupta',     'sanjay.gupta@erp.com',    '9876543221', '2015-09-01', 'Operations Manager',     5, NULL,  125000,'full-time', 'active'),
('Pooja',    'Tiwari',    'pooja.tiwari@erp.com',    '9876543222', '2023-01-16', 'Operations Analyst',     5, 12,    58000, 'full-time', 'active'),
-- Marketing
('Neha',     'Bose',      'neha.bose@erp.com',       '9876543223', '2019-07-22', 'Marketing Manager',      6, NULL,  100000,'full-time', 'active'),
('Arjun',    'Khanna',    'arjun.khanna@erp.com',    '9876543224', '2022-11-01', 'Marketing Analyst',      6, 14,    55000, 'full-time', 'active'),
-- Procurement
('Rahul',    'Mishra',    'rahul.mishra@erp.com',    '9876543225', '2020-03-05', 'Procurement Manager',    7, NULL,  95000, 'full-time', 'active'),
('Divya',    'Agarwal',   'divya.agarwal@erp.com',   '9876543226', '2022-07-18', 'Procurement Executive',  7, 16,    58000, 'full-time', 'active'),
-- Customer Support
('Kabir',    'Shah',      'kabir.shah@erp.com',      '9876543227', '2021-05-10', 'Support Manager',        8, NULL,  80000, 'full-time', 'active'),
('Tanya',    'Reddy',     'tanya.reddy@erp.com',     '9876543228', '2023-03-01', 'Support Agent',          8, 18,    42000, 'full-time', 'active'),
('Farhan',   'Khan',      'farhan.khan@erp.com',     '9876543229', '2023-09-01', 'Support Agent',          8, 18,    40000, 'full-time', 'active');

-- Set department heads
UPDATE departments SET head_employee_id = 1  WHERE department_id = 2;  -- HR
UPDATE departments SET head_employee_id = 3  WHERE department_id = 1;  -- Engineering
UPDATE departments SET head_employee_id = 7  WHERE department_id = 3;  -- Sales
UPDATE departments SET head_employee_id = 10 WHERE department_id = 4;  -- Finance
UPDATE departments SET head_employee_id = 12 WHERE department_id = 5;  -- Operations
UPDATE departments SET head_employee_id = 14 WHERE department_id = 6;  -- Marketing
UPDATE departments SET head_employee_id = 16 WHERE department_id = 7;  -- Procurement
UPDATE departments SET head_employee_id = 18 WHERE department_id = 8;  -- Customer Support

-- ATTENDANCE (last 7 days for active employees, sample)
INSERT INTO attendance (employee_id, work_date, check_in, check_out, hours_worked, status) VALUES
(1,  CURRENT_DATE - 1, '09:00', '18:00', 9,   'present'),
(2,  CURRENT_DATE - 1, '09:15', '18:00', 8.75,'present'),
(3,  CURRENT_DATE - 1, '08:50', '19:00', 10.2,'present'),
(4,  CURRENT_DATE - 1, '09:00', '18:30', 9.5, 'remote'),
(5,  CURRENT_DATE - 1, '10:00', '18:00', 8,   'present'),
(7,  CURRENT_DATE - 1, '09:00', '17:30', 8.5, 'present'),
(8,  CURRENT_DATE - 1, '09:30', '18:00', 8.5, 'present'),
(10, CURRENT_DATE - 1, NULL,    NULL,    0,    'absent'),
(12, CURRENT_DATE - 1, '08:45', '17:30', 8.75,'present'),
(3,  CURRENT_DATE - 2, '09:00', '18:00', 9,   'present'),
(4,  CURRENT_DATE - 2, '09:00', '18:00', 9,   'present'),
(5,  CURRENT_DATE - 2, '09:00', '13:00', 4,   'half-day');

-- LEAVE REQUESTS
INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, reason, status, approved_by) VALUES
(5,  'sick',    CURRENT_DATE - 10, CURRENT_DATE - 9,  'Fever and cold',       'approved', 3),
(8,  'casual',  CURRENT_DATE + 5,  CURRENT_DATE + 7,  'Personal work',        'pending',  NULL),
(4,  'earned',  CURRENT_DATE + 15, CURRENT_DATE + 22, 'Family vacation',      'approved', 3),
(2,  'sick',    CURRENT_DATE - 3,  CURRENT_DATE - 3,  'Doctor appointment',   'approved', 1),
(15, 'casual',  CURRENT_DATE - 5,  CURRENT_DATE - 5,  'Personal',             'approved', 14);

-- PAYROLL (last 3 months)
INSERT INTO payroll (employee_id, pay_period, basic_salary, allowances, deductions, tax, net_pay, paid_on, status) VALUES
(1,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '2 months'), 95000,  15000, 2000, 11000, 97000,  (CURRENT_DATE - INTERVAL '2 months' + '28 days'), 'paid'),
(3,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '2 months'), 145000, 20000, 3000, 19000, 143000, (CURRENT_DATE - INTERVAL '2 months' + '28 days'), 'paid'),
(7,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '2 months'), 110000, 18000, 2500, 15000, 110500, (CURRENT_DATE - INTERVAL '2 months' + '28 days'), 'paid'),
(10, DATE_TRUNC('month', CURRENT_DATE - INTERVAL '2 months'), 130000, 20000, 3000, 17000, 130000, (CURRENT_DATE - INTERVAL '2 months' + '28 days'), 'paid'),
(1,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'),  95000,  15000, 2000, 11000, 97000,  (CURRENT_DATE - INTERVAL '1 month'  + '28 days'), 'paid'),
(3,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'),  145000, 20000, 3000, 19000, 143000, (CURRENT_DATE - INTERVAL '1 month'  + '28 days'), 'paid'),
(4,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'),  120000, 18000, 2000, 16000, 120000, (CURRENT_DATE - INTERVAL '1 month'  + '28 days'), 'paid'),
(5,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'),  70000,  10000, 1000, 8000,  71000,  (CURRENT_DATE - INTERVAL '1 month'  + '28 days'), 'paid'),
(7,  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'),  110000, 18000, 2500, 15000, 110500, (CURRENT_DATE - INTERVAL '1 month'  + '28 days'), 'paid'),
(1,  DATE_TRUNC('month', CURRENT_DATE),                        95000,  15000, 2000, 11000, 97000,  NULL, 'pending'),
(3,  DATE_TRUNC('month', CURRENT_DATE),                        145000, 20000, 3000, 19000, 143000, NULL, 'pending');

-- WAREHOUSES
INSERT INTO warehouses (name, location, capacity, manager_id) VALUES
('Main Warehouse',    'Aurangabad, Maharashtra',  10000, 12),
('North Hub',         'Pune, Maharashtra',          5000, 12),
('South Distribution','Hyderabad, Telangana',       7500, 12);

-- PRODUCT CATEGORIES
INSERT INTO product_categories (name, description) VALUES
('Electronics',    'Electronic devices and components'),
('Office Supplies','Stationery and office equipment'),
('Furniture',      'Office and workplace furniture'),
('IT Hardware',    'Computers, servers, networking'),
('Raw Materials',  'Raw material for manufacturing');

INSERT INTO product_categories (name, parent_id) VALUES
('Laptops',        4),
('Servers',        4),
('Networking',     4),
('Peripherals',    4);

-- PRODUCTS
INSERT INTO products (sku, name, description, category_id, unit_price, cost_price, qty_in_stock, reorder_level, warehouse_id) VALUES
('LAP-001', 'Dell Latitude 5540',          '14-inch business laptop',              6,  85000,  65000,  45,  5,  1),
('LAP-002', 'Lenovo ThinkPad X1 Carbon',   'Ultralight enterprise laptop',         6,  120000, 95000,  20,  3,  1),
('LAP-003', 'HP EliteBook 840 G10',        '14-inch security-focused laptop',      6,  90000,  70000,  30,  5,  1),
('SRV-001', 'Dell PowerEdge R750',         '2U rack server 32-core',               7,  350000, 280000, 8,   2,  1),
('SRV-002', 'HPE ProLiant DL380 Gen10',    'Scalable enterprise server',           7,  420000, 340000, 5,   2,  1),
('NET-001', 'Cisco Catalyst 9200 Switch',  '24-port managed switch',               8,  55000,  42000,  15,  3,  2),
('NET-002', 'Ubiquiti UniFi AP-Pro',       'Enterprise WiFi 6 access point',       8,  18000,  13000,  40,  10, 2),
('PER-001', 'Dell 27 Monitor P2722H',      '27-inch FHD IPS monitor',              9,  22000,  16000,  60,  10, 1),
('PER-002', 'Logitech MX Keys Keyboard',   'Advanced wireless keyboard',           9,  8500,   6000,   80,  15, 1),
('OFF-001', 'A4 Paper Ream 500 sheets',    '80 GSM copy paper',                    2,  350,    250,    500, 50, 3),
('OFF-002', 'Stapler HD-50',               'Heavy duty stapler',                   2,  1200,   800,    100, 20, 3),
('FRN-001', 'Ergonomic Office Chair',      'Adjustable lumbar support chair',      3,  15000,  10000,  25,  5,  3),
('FRN-002', 'Standing Desk 140x70cm',      'Height adjustable desk',               3,  35000,  26000,  10,  3,  3),
('RAM-001', 'Aluminium Sheet 2mm',         'Grade 6061 aluminium sheet',           5,  2500,   1800,   200, 30, 1),
('RAM-002', 'Steel Rod 12mm dia',          'MS steel rod per meter',               5,  180,    120,    1000,100,1);

-- SUPPLIERS
INSERT INTO suppliers (name, contact_name, email, phone, city, payment_terms, rating) VALUES
('TechSource India Pvt Ltd',     'Manish Goyal',   'manish@techsource.in',   '9811223344', 'Mumbai',     30, 4.5),
('Office Mart Solutions',        'Kavita Pillai',  'kavita@officemart.in',   '9922334455', 'Pune',       15, 4.0),
('FurnCorner Enterprises',       'Suresh Nair',    'suresh@furncorner.in',   '9933445566', 'Bangalore',  45, 3.8),
('MetalFirst Industries',        'Ramesh Sharma',  'ramesh@metalfirst.in',   '9944556677', 'Aurangabad', 30, 4.2),
('NetworkPro Distributors',      'Lakshmi Iyer',   'lakshmi@netpro.in',      '9955667788', 'Chennai',    30, 4.7);

-- CUSTOMERS
INSERT INTO customers (name, email, phone, address, city, state, credit_limit, assigned_rep) VALUES
('Infosys Limited',          'procurement@infosys.com',     '8001112233', '44 Electronics City', 'Bangalore',  'Karnataka',    5000000, 8),
('Tata Consultancy Services','vendor@tcs.com',              '8002223344', 'TCS House, Raveline', 'Mumbai',     'Maharashtra',  8000000, 8),
('Wipro Technologies',       'supply@wipro.com',            '8003334455', 'Sarjapur Road',       'Bangalore',  'Karnataka',    4000000, 9),
('HCL Technologies',         'purchase@hcl.com',            '8004445566', 'Sector 125, Noida',   'Noida',      'UP',           3000000, 9),
('Mahindra & Mahindra',      'vendor.mgmt@mahindra.com',    '8005556677', 'Gateway Building',    'Mumbai',     'Maharashtra',  6000000, 7),
('Bajaj Auto Ltd',           'procurement@bajaj.com',       '8006667788', 'Akurdi, Pimpri',      'Pune',       'Maharashtra',  4500000, 7),
('Aurangabad Steel Works',   'purchase@aursteel.com',       '8007778899', 'MIDC, Chikalthana',   'Aurangabad', 'Maharashtra',  1500000, 9),
('Greenfield IT Solutions',  'info@greenfieldit.com',       '8008889900', 'Baner Road',          'Pune',       'Maharashtra',  2000000, 8);

-- SALES ORDERS
INSERT INTO sales_orders (customer_id, order_date, expected_delivery, status, total_amount, discount, tax_amount, created_by) VALUES
(1, CURRENT_DATE - 45, CURRENT_DATE - 30, 'delivered',   5100000, 5, 918000,  8),
(2, CURRENT_DATE - 30, CURRENT_DATE - 15, 'delivered',   2550000, 3, 459000,  8),
(3, CURRENT_DATE - 20, CURRENT_DATE - 5,  'shipped',     1700000, 0, 306000,  9),
(4, CURRENT_DATE - 10, CURRENT_DATE + 5,  'processing',  850000,  2, 153000,  9),
(5, CURRENT_DATE - 5,  CURRENT_DATE + 10, 'confirmed',   4200000, 5, 756000,  7),
(6, CURRENT_DATE - 2,  CURRENT_DATE + 14, 'pending',     720000,  0, 129600,  7),
(1, CURRENT_DATE,      CURRENT_DATE + 20, 'pending',     1020000, 5, 183600,  8),
(7, CURRENT_DATE - 60, CURRENT_DATE - 45, 'cancelled',   360000,  0, 64800,   9);

-- SALES ORDER ITEMS
INSERT INTO sales_order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 30, 85000), (1, 7, 50, 18000),
(2, 2, 15, 120000),(2, 8, 30, 22000),
(3, 3, 10, 90000), (3, 6,  5, 55000),
(4, 1,  5, 85000), (4, 9, 20, 8500),
(5, 4,  8, 350000),(5, 6, 10, 55000),
(6, 1,  5, 85000), (6, 7, 15, 18000),
(7, 2,  5, 120000),(7, 8, 10, 22000),
(8, 1,  4, 85000), (8, 7,  2, 18000);

-- INVOICES
INSERT INTO invoices (order_id, customer_id, invoice_date, due_date, amount, amount_paid, status, payment_method) VALUES
(1, 1, CURRENT_DATE - 44, CURRENT_DATE - 14, 5100000, 5100000, 'paid',    'NEFT'),
(2, 2, CURRENT_DATE - 29, CURRENT_DATE + 1,  2550000, 2550000, 'paid',    'RTGS'),
(3, 3, CURRENT_DATE - 19, CURRENT_DATE + 11, 1700000, 850000,  'partial', 'Cheque'),
(4, 4, CURRENT_DATE - 9,  CURRENT_DATE + 21, 850000,  0,       'unpaid',  NULL),
(5, 5, CURRENT_DATE - 4,  CURRENT_DATE + 26, 4200000, 0,       'unpaid',  NULL),
(6, 6, CURRENT_DATE - 1,  CURRENT_DATE + 29, 720000,  0,       'unpaid',  NULL);

-- PURCHASE ORDERS
INSERT INTO purchase_orders (supplier_id, po_date, expected_date, status, total_amount, created_by) VALUES
(1, CURRENT_DATE - 60, CURRENT_DATE - 30, 'received',  2600000, 16),
(1, CURRENT_DATE - 20, CURRENT_DATE - 5,  'received',  1800000, 16),
(2, CURRENT_DATE - 15, CURRENT_DATE - 2,  'confirmed', 175000,  17),
(3, CURRENT_DATE - 10, CURRENT_DATE + 5,  'sent',      500000,  16),
(4, CURRENT_DATE - 5,  CURRENT_DATE + 10, 'draft',     360000,  17),
(5, CURRENT_DATE - 3,  CURRENT_DATE + 7,  'confirmed', 280000,  16);

-- PURCHASE ORDER ITEMS
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_cost) VALUES
(1, 1, 20, 65000),(1, 3, 10, 70000),
(2, 2, 10, 95000),(2, 8, 20, 16000),
(3, 10,200, 250), (3,11, 50, 800),
(4, 12, 20,10000),(4,13, 5, 26000),
(5, 14,100,1800), (5,15,500, 120),
(6, 6,  5,42000), (6, 7,10, 13000);

-- STOCK MOVEMENTS (sample)
INSERT INTO stock_movements (product_id, movement_type, quantity, reference_id, reference_type, notes) VALUES
(1, 'purchase',   20, 1, 'purchase_order', 'PO-001 received'),
(1, 'sale',      -30, 1, 'sales_order',    'SO-001 fulfilled'),
(2, 'purchase',   10, 2, 'purchase_order', 'PO-002 received'),
(2, 'sale',      -15, 2, 'sales_order',    'SO-002 fulfilled'),
(7, 'sale',      -50, 1, 'sales_order',    'SO-001 fulfilled'),
(8, 'purchase',   20, 2, 'purchase_order', 'PO-002 received'),
(8, 'sale',      -30, 2, 'sales_order',    'SO-002 fulfilled'),
(1, 'adjustment',  5, NULL, NULL,          'Cycle count correction');

-- CHART OF ACCOUNTS
INSERT INTO accounts (account_code, name, account_type, balance) VALUES
('1000', 'Cash and Cash Equivalents',   'asset',     12500000),
('1100', 'Accounts Receivable',         'asset',     6770000),
('1200', 'Inventory',                   'asset',     8950000),
('1300', 'Prepaid Expenses',            'asset',     450000),
('2000', 'Accounts Payable',            'liability', 3110000),
('2100', 'Short-term Loans',            'liability', 5000000),
('3000', 'Retained Earnings',           'equity',    18000000),
('4000', 'Product Revenue',             'revenue',   15120000),
('4100', 'Service Revenue',             'revenue',   2300000),
('5000', 'Cost of Goods Sold',          'expense',   8900000),
('5100', 'Salaries Expense',            'expense',   1850000),
('5200', 'Rent Expense',                'expense',   360000),
('5300', 'Marketing Expense',           'expense',   520000),
('5400', 'Utilities Expense',           'expense',   180000);

-- JOURNAL ENTRIES
INSERT INTO journal_entries (entry_date, description, reference, created_by, posted) VALUES
(CURRENT_DATE - 44, 'Invoice payment received from Infosys',          'INV-001', 11, TRUE),
(CURRENT_DATE - 29, 'Invoice payment received from TCS',              'INV-002', 11, TRUE),
(CURRENT_DATE - 1,  'Monthly salary disbursement',                    'PAY-MAR', 11, TRUE),
(CURRENT_DATE,      'Purchase of laptops from TechSource',            'PO-002',  11, FALSE);

INSERT INTO journal_lines (entry_id, account_id, debit, credit, description) VALUES
(1, 1,  5100000, 0,       'Cash received'), (1, 2, 0, 5100000, 'AR cleared'),
(2, 1,  2550000, 0,       'Cash received'), (2, 2, 0, 2550000, 'AR cleared'),
(3, 11, 1850000, 0,       'March salaries'),(3, 1, 0, 1850000, 'Bank payment'),
(4, 3,  1800000, 0,       'Inventory in'),  (4, 5, 0, 1800000, 'AP recorded');

-- CRM LEADS
INSERT INTO crm_leads (name, company, email, phone, source, status, estimated_value, assigned_to, notes) VALUES
('Ramesh Agarwal',  'Future Tech Ltd',     'ramesh@futuretech.in',  '9101112233', 'website',   'qualified', 2500000,  8,  'Needs 20 laptops + servers'),
('Sunita Pillai',   'Coastal Exports',     'sunita@coastal.in',     '9202223344', 'referral',  'proposal',  1800000,  9,  'Networking setup for 3 offices'),
('Dev Malhotra',    'StartupXYZ',          'dev@startupxyz.com',    '9303334455', 'cold-call', 'contacted', 500000,   8,  'Small office setup'),
('Preethi Kumar',   'MNC India Pvt Ltd',   'preethi@mncindia.com',  '9404445566', 'website',   'new',       8000000,  7,  'Large enterprise deal'),
('Arif Mohammad',   'Regional Bank Ltd',   'arif@regbank.in',       '9505556677', 'referral',  'won',       3200000,  9,  'Server infrastructure project'),
('Lata Krishnan',   'AutoParts Mfg',       'lata@autoparts.in',     '9606667788', 'cold-call', 'lost',      750000,   8,  'Went with competitor'),
('Nikhil Verma',    'EduTech Solutions',   'nikhil@edutech.in',     '9707778899', 'website',   'contacted', 1200000,  9,  'Smart classroom project');
