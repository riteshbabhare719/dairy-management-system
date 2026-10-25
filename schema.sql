-- ============================================================
-- Dairy Milk Collection Management System - PostgreSQL Schema
-- Database: dairy (10 Tables + 1 View + 20 Sample Entries Each)
-- ============================================================

-- ── 1. Drop existing objects in reverse dependency order ──────
DROP VIEW IF EXISTS v_daily_summary CASCADE;
DROP TABLE IF EXISTS quality_tests CASCADE;
DROP TABLE IF EXISTS complaints CASCADE;
DROP TABLE IF EXISTS expenses CASCADE;
DROP TABLE IF EXISTS cattle CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS collection CASCADE;
DROP TABLE IF EXISTS farmers CASCADE;
DROP TABLE IF EXISTS milk_types CASCADE;

-- ── 2. Create Tables ──────────────────────────────────────────

-- Table 1: milk_types
CREATE TABLE milk_types (
    milk_type_id SERIAL       PRIMARY KEY,
    type_name    VARCHAR(30)  NOT NULL UNIQUE,
    base_rate    NUMERIC(8,2) NOT NULL CHECK (base_rate > 0),
    description  VARCHAR(100)
);

-- Table 2: farmers
CREATE TABLE farmers (
    farmer_id   SERIAL      PRIMARY KEY,
    farmer_name VARCHAR(80) NOT NULL,
    village     VARCHAR(60) NOT NULL,
    phone       CHAR(10)    NOT NULL UNIQUE,
    join_date   DATE        NOT NULL DEFAULT CURRENT_DATE,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE
);

-- Table 3: collection
CREATE TABLE collection (
    id              SERIAL        PRIMARY KEY,
    farmer_id       INTEGER       NOT NULL REFERENCES farmers(farmer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    milk_type_id    SMALLINT      NOT NULL REFERENCES milk_types(milk_type_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    shift           VARCHAR(10)   NOT NULL DEFAULT 'Morning' CHECK (shift IN ('Morning','Evening')),
    quantity        NUMERIC(8,2)  NOT NULL CHECK (quantity > 0),
    fat_percentage  NUMERIC(4,1)  NOT NULL CHECK (fat_percentage BETWEEN 0 AND 15),
    rate            NUMERIC(8,2)  NOT NULL CHECK (rate > 0),
    total_amount    NUMERIC(10,2) GENERATED ALWAYS AS (quantity * rate) STORED,
    collection_date DATE          NOT NULL DEFAULT CURRENT_DATE,
    remarks         VARCHAR(150)
);

-- Table 4: payments
CREATE TABLE payments (
    payment_id   SERIAL        PRIMARY KEY,
    farmer_id    INTEGER       NOT NULL REFERENCES farmers(farmer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    period_from  DATE          NOT NULL,
    period_to    DATE          NOT NULL,
    amount_paid  NUMERIC(12,2) NOT NULL CHECK (amount_paid >= 0),
    payment_date DATE          NOT NULL DEFAULT CURRENT_DATE,
    payment_mode VARCHAR(20)   NOT NULL DEFAULT 'UPI' CHECK (payment_mode IN ('Cash','Bank Transfer','UPI')),
    CONSTRAINT chk_period CHECK (period_to >= period_from)
);

-- Table 5: employees
CREATE TABLE employees (
    emp_id    SERIAL        PRIMARY KEY,
    emp_name  VARCHAR(80)   NOT NULL,
    role      VARCHAR(50)   NOT NULL,
    phone     CHAR(10)      NOT NULL UNIQUE,
    salary    NUMERIC(10,2) NOT NULL CHECK (salary > 0),
    join_date DATE          NOT NULL,
    is_active BOOLEAN       NOT NULL DEFAULT TRUE
);

-- Table 6: vehicles
CREATE TABLE vehicles (
    vehicle_id      SERIAL       PRIMARY KEY,
    vehicle_no      VARCHAR(15)  NOT NULL UNIQUE,
    vehicle_type    VARCHAR(40)  NOT NULL,
    capacity_liters NUMERIC(8,2) NOT NULL,
    driver_name     VARCHAR(80)  NOT NULL,
    driver_phone    CHAR(10)     NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Table 7: cattle
CREATE TABLE cattle (
    cattle_id   SERIAL      PRIMARY KEY,
    farmer_id   INTEGER     NOT NULL REFERENCES farmers(farmer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    animal_type VARCHAR(10) NOT NULL CHECK (animal_type IN ('Cow','Buffalo','Goat')),
    breed       VARCHAR(50) NOT NULL,
    age_years   SMALLINT    NOT NULL,
    tag_number  VARCHAR(20) NOT NULL UNIQUE,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE
);

-- Table 8: quality_tests
CREATE TABLE quality_tests (
    test_id       SERIAL       PRIMARY KEY,
    collection_id INTEGER      NOT NULL REFERENCES collection(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    tested_by     VARCHAR(80)  NOT NULL,
    fat_pct       NUMERIC(4,1) NOT NULL,
    snf_pct       NUMERIC(4,1) NOT NULL,
    clr           NUMERIC(5,1) NOT NULL,
    temperature_c NUMERIC(4,1) NOT NULL,
    result        VARCHAR(10)  NOT NULL DEFAULT 'Pass' CHECK (result IN ('Pass','Fail','Retest')),
    test_date     DATE         NOT NULL
);

-- Table 9: complaints
CREATE TABLE complaints (
    complaint_id   SERIAL       PRIMARY KEY,
    farmer_id      INTEGER      NOT NULL REFERENCES farmers(farmer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    complaint_type VARCHAR(60)  NOT NULL,
    description    VARCHAR(200) NOT NULL,
    status         VARCHAR(15)  NOT NULL DEFAULT 'Open' CHECK (status IN ('Open','In Progress','Resolved')),
    filed_date     DATE         NOT NULL,
    resolved_date  DATE
);

-- Table 10: expenses
CREATE TABLE expenses (
    expense_id   SERIAL        PRIMARY KEY,
    category     VARCHAR(60)   NOT NULL,
    description  VARCHAR(150)  NOT NULL,
    amount       NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    expense_date DATE          NOT NULL,
    paid_to      VARCHAR(80)   NOT NULL,
    payment_mode VARCHAR(20)   NOT NULL DEFAULT 'Cash' CHECK (payment_mode IN ('Cash','Bank Transfer','UPI'))
);

-- ── 3. View: v_daily_summary ──────────────────────────────────
CREATE OR REPLACE VIEW v_daily_summary AS
SELECT
    c.collection_date,
    mt.type_name  AS type_name,
    c.shift,
    COUNT(*)            AS collections,
    SUM(c.quantity)     AS total_litres,
    SUM(c.total_amount) AS total_amount
FROM collection c
JOIN milk_types mt ON c.milk_type_id = mt.milk_type_id
GROUP BY c.collection_date, mt.type_name, c.shift;


-- ── 4. Seed Data (20 Entries per Table) ────────────────────────

-- Table 1: milk_types
INSERT INTO milk_types (type_name, base_rate, description) VALUES
('Cow',     32.00, 'Fresh cow milk, lower fat content'),
('Buffalo', 42.00, 'Rich buffalo milk, higher fat content'),
('Goat',    55.00, 'Premium goat milk, specialty segment');

-- Table 2: farmers (20 rows)
INSERT INTO farmers (farmer_name, village, phone, join_date, is_active) VALUES
('Ramesh Patil',    'Shirwal',    '9822011234', '2023-01-15', TRUE),
('Suresh Shinde',   'Khandala',   '9822022345', '2023-02-10', TRUE),
('Anand Kadam',     'Shirwal',    '9822033456', '2023-03-05', TRUE),
('Vijay Bhosale',   'Lonand',     '9822044567', '2023-03-20', TRUE),
('Prakash Jadhav',  'Bhuinj',     '9822055678', '2023-04-12', TRUE),
('Dilip Pawar',     'Khandala',   '9822066789', '2023-05-01', TRUE),
('Sunil Chavan',    'Shirwal',    '9822077890', '2023-05-18', TRUE),
('Mahesh Gaikwad',  'Wai',        '9822088901', '2023-06-02', TRUE),
('Santosh More',    'Lonand',     '9822099012', '2023-06-25', TRUE),
('Dattatray Mane',  'Bhuinj',     '9822100123', '2023-07-10', TRUE),
('Ganesh Salunkhe', 'Shirwal',    '9822111234', '2023-07-28', TRUE),
('Balasaheb Jagtap','Khandala',   '9822122345', '2023-08-14', TRUE),
('Pandurang Nalawade','Wai',      '9822133456', '2023-08-30', TRUE),
('Tanaji Thorat',   'Lonand',     '9822144567', '2023-09-12', TRUE),
('Shivaji Ghadge',  'Bhuinj',     '9822155678', '2023-09-27', TRUE),
('Baban Sawant',    'Shirwal',    '9822166789', '2023-10-05', TRUE),
('Namdeo Pisal',    'Khandala',   '9822177890', '2023-10-18', TRUE),
('Ramdas Mohite',   'Wai',        '9822188901', '2023-11-02', TRUE),
('Kishor Deshmukh', 'Lonand',     '9822199012', '2023-11-20', FALSE),
('Arun Gole',       'Bhuinj',     '9822200123', '2023-12-01', TRUE);

-- Table 3: collection (25 rows)
INSERT INTO collection (farmer_id, milk_type_id, shift, quantity, fat_percentage, rate, collection_date, remarks) VALUES
(1,  1, 'Morning', 12.50, 4.2, 35.00, '2024-10-01', 'Good quality'),
(2,  2, 'Morning', 20.00, 6.8, 44.00, '2024-10-01', NULL),
(3,  1, 'Morning',  8.00, 3.8, 33.00, '2024-10-01', NULL),
(4,  2, 'Evening', 15.00, 7.1, 45.00, '2024-10-01', 'High fat evening batch'),
(5,  1, 'Evening', 10.00, 4.0, 34.00, '2024-10-01', NULL),
(6,  1, 'Morning', 14.00, 4.5, 36.00, '2024-10-02', NULL),
(7,  2, 'Morning', 18.50, 6.5, 43.00, '2024-10-02', NULL),
(8,  2, 'Evening', 22.00, 7.0, 45.00, '2024-10-02', 'Best yield'),
(9,  1, 'Evening',  9.50, 3.9, 33.50, '2024-10-02', NULL),
(10, 2, 'Morning', 16.00, 6.7, 44.00, '2024-10-03', NULL),
(1,  1, 'Morning', 13.00, 4.1, 34.50, '2024-10-03', NULL),
(2,  2, 'Evening', 19.00, 6.9, 44.50, '2024-10-03', NULL),
(11, 1, 'Morning', 11.00, 4.0, 34.00, '2024-10-04', NULL),
(12, 2, 'Morning', 25.00, 7.2, 46.00, '2024-10-04', 'Excellent batch'),
(13, 1, 'Evening',  7.50, 3.7, 32.50, '2024-10-04', NULL),
(14, 1, 'Morning', 10.50, 4.3, 35.50, '2024-10-05', NULL),
(15, 2, 'Morning', 14.00, 6.6, 43.50, '2024-10-05', NULL),
(16, 2, 'Evening', 21.00, 7.0, 45.00, '2024-10-05', NULL),
(17, 1, 'Evening', 12.00, 4.1, 34.50, '2024-10-05', NULL),
(18, 2, 'Morning', 17.50, 6.8, 44.00, '2024-10-06', NULL),
(3,  1, 'Morning',  9.00, 3.9, 33.50, '2024-10-06', NULL),
(4,  2, 'Evening', 16.50, 7.1, 45.00, '2024-10-06', NULL),
(19, 1, 'Evening',  6.00, 3.3, 31.00, '2024-10-07', 'Low quantity day'),
(20, 2, 'Morning', 17.00, 6.6, 42.00, '2024-10-07', NULL),
(1,  1, 'Evening', 11.50, 3.7, 32.00, '2024-10-07', NULL);

-- Table 4: payments (20 rows)
INSERT INTO payments (farmer_id, period_from, period_to, amount_paid, payment_date, payment_mode) VALUES
(1,  '2024-09-01', '2024-09-15',  850.00, '2024-09-17', 'UPI'),
(2,  '2024-09-01', '2024-09-15', 1260.00, '2024-09-17', 'Bank Transfer'),
(3,  '2024-09-01', '2024-09-15',  700.00, '2024-09-17', 'Cash'),
(4,  '2024-09-01', '2024-09-15', 1540.00, '2024-09-17', 'Bank Transfer'),
(5,  '2024-09-01', '2024-09-15',  990.00, '2024-09-17', 'UPI'),
(6,  '2024-09-01', '2024-09-15',  550.00, '2024-09-17', 'Cash'),
(7,  '2024-09-01', '2024-09-15',  704.00, '2024-09-17', 'UPI'),
(8,  '2024-09-01', '2024-09-15', 1700.00, '2024-09-17', 'Bank Transfer'),
(9,  '2024-09-01', '2024-09-15',  620.00, '2024-09-17', 'UPI'),
(10, '2024-09-01', '2024-09-15', 1344.00, '2024-09-17', 'Bank Transfer'),
(1,  '2024-09-16', '2024-09-30',  880.00, '2024-10-02', 'UPI'),
(2,  '2024-09-16', '2024-09-30', 1300.00, '2024-10-02', 'Bank Transfer'),
(11, '2024-09-01', '2024-09-30',  830.00, '2024-10-02', 'Cash'),
(12, '2024-09-01', '2024-09-30', 2100.00, '2024-10-02', 'Bank Transfer'),
(13, '2024-09-01', '2024-09-30',  480.00, '2024-10-02', 'UPI'),
(14, '2024-09-01', '2024-09-30',  440.00, '2024-10-02', 'Cash'),
(15, '2024-09-01', '2024-09-30',  640.00, '2024-10-02', 'UPI'),
(16, '2024-09-01', '2024-09-30', 1596.00, '2024-10-03', 'Bank Transfer'),
(17, '2024-09-01', '2024-09-30',  910.00, '2024-10-03', 'UPI'),
(18, '2024-09-01', '2024-09-30', 1849.00, '2024-10-03', 'Bank Transfer');

-- Table 5: employees (20 rows)
INSERT INTO employees (emp_name, role, phone, salary, join_date, is_active) VALUES
('Sunil Kulkarni',    'Manager',             '9711011111', 45000.00, '2022-01-10', TRUE),
('Nilesh Patil',      'Quality Inspector',   '9711022222', 28000.00, '2022-03-15', TRUE),
('Vikas Deshmukh',    'Lab Technician',      '9711033333', 24000.00, '2022-04-01', TRUE),
('Sagar Ghuge',       'Collection Officer',  '9711044444', 22000.00, '2022-06-10', TRUE),
('Amit Shinde',       'Collection Officer',  '9711055555', 22000.00, '2022-07-20', TRUE),
('Rohan Jagtap',      'Accountant',          '9711066666', 32000.00, '2022-09-01', TRUE),
('Pooja Kadam',       'Data Entry Operator', '9711077777', 18000.00, '2023-01-15', TRUE),
('Sneha Pawar',       'Data Entry Operator', '9711088888', 18000.00, '2023-02-10', TRUE),
('Santosh Ghadge',    'Driver',              '9711099999', 20000.00, '2023-03-01', TRUE),
('Kiran More',        'Driver',              '9711100000', 20000.00, '2023-03-15', TRUE),
('Deepak Chavan',     'Driver',              '9711111111', 20000.00, '2023-04-01', TRUE),
('Mahesh Salunkhe',   'Driver',              '9711122222', 20000.00, '2023-05-10', TRUE),
('Anil Jadhav',       'Helper',              '9711133333', 14000.00, '2023-06-01', TRUE),
('Sachin Nalawade',   'Helper',              '9711144444', 14000.00, '2023-06-15', TRUE),
('Rahul Pisal',       'Helper',              '9711155555', 14000.00, '2023-07-01', TRUE),
('Datta Thorat',      'Security Guard',      '9711166666', 15000.00, '2023-08-01', TRUE),
('Pandurang Gole',    'Security Guard',      '9711177777', 15000.00, '2023-08-15', TRUE),
('Ashok Mohite',      'Maintenance Tech',    '9711188888', 22000.00, '2023-09-01', TRUE),
('Vijay Sawant',      'Supervisor',          '9711199999', 30000.00, '2023-10-01', TRUE),
('Pravin Mane',       'Collection Officer',  '9711200000', 22000.00, '2023-11-01', TRUE);

-- Table 6: vehicles (20 rows)
INSERT INTO vehicles (vehicle_no, vehicle_type, capacity_liters, driver_name, driver_phone, is_active) VALUES
('MH-11-AA-1001', 'Insulated Tanker', 5000.00, 'Santosh Ghadge',  '9711099999', TRUE),
('MH-11-AA-1002', 'Insulated Tanker', 5000.00, 'Kiran More',      '9711100000', TRUE),
('MH-11-AA-1003', 'Insulated Tanker', 3000.00, 'Deepak Chavan',   '9711111111', TRUE),
('MH-11-AA-1004', 'Collection Van',   1500.00, 'Mahesh Salunkhe', '9711122222', TRUE),
('MH-11-AA-1005', 'Collection Van',   1500.00, 'Anil Jadhav',     '9711133333', TRUE),
('MH-11-AA-1006', 'Insulated Tanker', 5000.00, 'Sachin Nalawade', '9711144444', TRUE),
('MH-11-AA-1007', 'Collection Van',   2000.00, 'Rahul Pisal',     '9711155555', TRUE),
('MH-11-AA-1008', 'Collection Van',   1500.00, 'Datta Thorat',    '9711166666', TRUE),
('MH-11-AA-1009', 'Insulated Tanker', 8000.00, 'Santosh Ghadge',  '9711099999', TRUE),
('MH-11-AA-1010', 'Collection Van',   2000.00, 'Kiran More',      '9711100000', TRUE),
('MH-11-AA-1011', 'Collection Van',   1500.00, 'Deepak Chavan',   '9711111111', TRUE),
('MH-11-AA-1012', 'Insulated Tanker', 3000.00, 'Mahesh Salunkhe', '9711122222', TRUE),
('MH-11-AA-1013', 'Collection Van',   1200.00, 'Anil Jadhav',     '9711133333', TRUE),
('MH-11-AA-1014', 'Collection Van',   1500.00, 'Sachin Nalawade', '9711144444', TRUE),
('MH-11-AA-1015', 'Insulated Tanker', 5000.00, 'Rahul Pisal',     '9711155555', TRUE),
('MH-11-AA-1016', 'Collection Van',   1500.00, 'Datta Thorat',    '9711166666', TRUE),
('MH-11-AA-1017', 'Insulated Tanker', 3000.00, 'Pandurang Gole',  '9711177777', TRUE),
('MH-11-AA-1018', 'Collection Van',   2000.00, 'Ashok Mohite',    '9711188888', TRUE),
('MH-11-AA-1019', 'Collection Van',   1500.00, 'Vijay Sawant',    '9711199999', TRUE),
('MH-11-AA-1020', 'Insulated Tanker', 5000.00, 'Pravin Mane',     '9711200000', TRUE);

-- Table 7: cattle (20 rows)
INSERT INTO cattle (farmer_id, animal_type, breed, age_years, tag_number, is_active) VALUES
(1,  'Cow',     'Gir',         4, 'TAG-COW-001', TRUE),
(1,  'Cow',     'Jersey',      3, 'TAG-COW-002', TRUE),
(2,  'Buffalo', 'Murrah',      5, 'TAG-BUF-001', TRUE),
(2,  'Buffalo', 'Murrah',      4, 'TAG-BUF-002', TRUE),
(3,  'Cow',     'Holstein',    3, 'TAG-COW-003', TRUE),
(4,  'Buffalo', 'Jaffarabadi', 6, 'TAG-BUF-003', TRUE),
(5,  'Cow',     'Sahiwal',     4, 'TAG-COW-004', TRUE),
(6,  'Cow',     'Gir',         5, 'TAG-COW-005', TRUE),
(7,  'Buffalo', 'Surti',       4, 'TAG-BUF-004', TRUE),
(8,  'Buffalo', 'Murrah',      3, 'TAG-BUF-005', TRUE),
(9,  'Cow',     'Jersey',      4, 'TAG-COW-006', TRUE),
(10, 'Buffalo', 'Murrah',      5, 'TAG-BUF-006', TRUE),
(11, 'Cow',     'Gir',         3, 'TAG-COW-007', TRUE),
(12, 'Buffalo', 'Murrah',      6, 'TAG-BUF-007', TRUE),
(13, 'Cow',     'Sahiwal',     4, 'TAG-COW-008', TRUE),
(14, 'Cow',     'Holstein',    3, 'TAG-COW-009', TRUE),
(15, 'Buffalo', 'Jaffarabadi', 5, 'TAG-BUF-008', TRUE),
(16, 'Buffalo', 'Murrah',      4, 'TAG-BUF-009', TRUE),
(17, 'Cow',     'Gir',         5, 'TAG-COW-010', TRUE),
(18, 'Buffalo', 'Murrah',      4, 'TAG-BUF-010', TRUE);

-- Table 8: quality_tests (20 rows - matches actual collection records)
INSERT INTO quality_tests (collection_id, tested_by, fat_pct, snf_pct, clr, temperature_c, result, test_date)
SELECT
    c.id,
    CASE (ROW_NUMBER() OVER (ORDER BY c.id) % 3)
        WHEN 1 THEN 'Nilesh Patil'
        WHEN 2 THEN 'Vikas Deshmukh'
        ELSE        'Sagar Ghuge'
    END AS tested_by,
    c.fat_percentage                         AS fat_pct,
    ROUND((c.fat_percentage + 4.7)::numeric, 1) AS snf_pct,
    CASE WHEN c.milk_type_id = 2 THEN 26.8 ELSE 27.8 END AS clr,
    4.2                                      AS temperature_c,
    CASE
        WHEN c.fat_percentage < 3.4 THEN 'Fail'
        WHEN c.fat_percentage < 3.6 THEN 'Retest'
        ELSE 'Pass'
    END AS result,
    c.collection_date AS test_date
FROM collection c
ORDER BY c.id
LIMIT 20;

-- Table 9: complaints (20 rows)
INSERT INTO complaints (farmer_id, complaint_type, description, status, filed_date, resolved_date) VALUES
(1,  'Rate Discrepancy',     'Rate calculated was lower than agreed base rate', 'Resolved',    '2024-09-05', '2024-09-07'),
(2,  'Delayed Payment',      'Payment for 1-15 Sep was delayed by 3 days',      'Resolved',    '2024-09-18', '2024-09-20'),
(3,  'Fat Testing Issue',    'Fat percentage tested lower than home test',      'In Progress', '2024-09-22', NULL),
(4,  'Shift Timing',         'Evening collection vehicle arrived late by 1 hr', 'Resolved',    '2024-09-25', '2024-09-26'),
(5,  'Measurement Discrepancy','Quantity measured 1 liter less than actual',   'Open',        '2024-10-01', NULL),
(6,  'Payment Not Received', 'UPI payment failed for previous cycle',          'In Progress', '2024-10-02', NULL),
(7,  'App Not Updating',     'Daily collection not reflecting in passbook',     'Resolved',    '2024-10-02', '2024-10-03'),
(8,  'Staff Behavior',       'Collection officer was rude during evening shift','Resolved',    '2024-10-03', '2024-10-04'),
(9,  'Fat Testing Issue',    'Fat percentage mismatch in consecutive shifts',   'Open',        '2024-10-03', NULL),
(10, 'Delayed Payment',      'September cycle 2 payment pending',               'Open',        '2024-10-04', NULL),
(11, 'Can Damaged',          'Milk can was dented during transport',            'Resolved',    '2024-10-04', '2024-10-05'),
(12, 'Route Missed',         'Morning collection van missed Lonand stop',       'Resolved',    '2024-10-04', '2024-10-04'),
(13, 'Rate Discrepancy',     'Cow milk rate applied to Buffalo batch',          'In Progress', '2024-10-05', NULL),
(14, 'Fat Testing Issue',    'Lactometer reading questioned by farmer',         'Open',        '2024-10-05', NULL),
(15, 'Delayed Payment',      'Payment credited to wrong account',               'In Progress', '2024-10-05', NULL),
(16, 'Measurement Discrepancy','Weight machine not calibrated properly',       'Resolved',    '2024-10-06', '2024-10-06'),
(17, 'Shift Timing',         'Morning shift closed 15 minutes early',           'Resolved',    '2024-10-06', '2024-10-07'),
(18, 'Staff Behavior',       'Dispute with tester over SNF percentage',         'In Progress', '2024-10-06', NULL),
(19, 'Rate Discrepancy',     'Deduction made without explanation',              'Open',        '2024-10-07', NULL),
(20, 'Payment Not Received', 'Cheque bounced due to signature mismatch',        'Open',        '2024-10-07', NULL);

-- Table 10: expenses (20 rows)
INSERT INTO expenses (category, description, amount, expense_date, paid_to, payment_mode) VALUES
('Fuel',            'Diesel for vehicle MH-11-AA-1001',    4500.00, '2024-10-01', 'Indian Oil Petrol Pump',  'UPI'),
('Testing Supplies','Lactometers and chemical reagents',   3200.00, '2024-10-01', 'Dairy Equipments Pune',   'Bank Transfer'),
('Salaries',        'Advance salary to driver Santosh',    5000.00, '2024-10-02', 'Santosh Ghadge',          'Cash'),
('Vehicle Maintenance','Oil change MH-11-AA-1002',         2800.00, '2024-10-02', 'Patil Auto Garage',       'Cash'),
('Fuel',            'Diesel for vehicle MH-11-AA-1004',    3800.00, '2024-10-03', 'Bharat Petroleum',        'UPI'),
('Electricity',     'Chilling center electricity bill Sep',12400.00,'2024-10-03', 'MSEDCL',                  'Bank Transfer'),
('Printing',        'Farmer passbooks and payment slips',  1800.00, '2024-10-03', 'Shivaji Printers Wai',    'Cash'),
('Fuel',            'Diesel for vehicle MH-11-AA-1003',    4200.00, '2024-10-04', 'Indian Oil Petrol Pump',  'UPI'),
('Cleaning Supplies','Detergents and sanitizers for cans', 2100.00, '2024-10-04', 'Swastik Chemical Store', 'Cash'),
('Vehicle Maintenance','Tyre replacement MH-11-AA-1001',   8500.00, '2024-10-04', 'MRF Tyre Agency Wai',     'Bank Transfer'),
('Fuel',            'Diesel for vehicle MH-11-AA-1005',    3600.00, '2024-10-05', 'Bharat Petroleum',        'UPI'),
('Office Supplies', 'Registers pens and printer paper',     950.00, '2024-10-05', 'Navneet Stationery',      'Cash'),
('Water',           'Water tanker for chilling center',    2500.00, '2024-10-05', 'Gaikwad Water Supplier',  'Cash'),
('Internet',        'Broadband bill for office Sep',       1200.00, '2024-10-05', 'BSNL',                    'UPI'),
('Fuel',            'Diesel for vehicle MH-11-AA-1002',    4100.00, '2024-10-06', 'Indian Oil Petrol Pump',  'UPI'),
('Software AMC',    'Monthly billing software support',    3500.00, '2024-10-06', 'DairyTech Solutions',     'Bank Transfer'),
('Vehicle Maintenance','Brake repair MH-11-AA-1004',       1600.00, '2024-10-06', 'Patil Auto Garage',       'Cash'),
('Fuel',            'Diesel for vehicle MH-11-AA-1006',    4800.00, '2024-10-07', 'Bharat Petroleum',        'UPI'),
('Testing Supplies','Sample bottles and ice boxes',        1400.00, '2024-10-07', 'Dairy Equipments Pune',   'Cash'),
('Miscellaneous',   'Tea and refreshments for meetings',    650.00, '2024-10-07', 'Hotel Virasat',           'Cash');
