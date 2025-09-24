-- ecommerce_schema.sql
-- E-commerce Store Database Schema (MySQL)
-- Creates database, tables, constraints and relationships
-- Engine: InnoDB, Charset: utf8mb4

DROP DATABASE IF EXISTS ecommerce_store;
CREATE DATABASE ecommerce_store CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
USE ecommerce_store;

-- ==================================================================
-- Notes:
-- - InnoDB used to support foreign keys/transactions
-- - CHECK constraints included where MySQL supports them (>=8.0.16 they are enforced)
-- ==================================================================

-- -------------------------
-- Lookup / reference tables
-- -------------------------
CREATE TABLE roles (
    role_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

INSERT INTO roles (role_name) VALUES ('customer'), ('admin'), ('vendor');

CREATE TABLE order_status (
    status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

INSERT INTO order_status (status_name) VALUES ('pending'), ('paid'), ('processing'), ('shipped'), ('delivered'), ('cancelled'), ('refunded');

CREATE TABLE payment_methods (
    payment_method_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    method_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

INSERT INTO payment_methods (method_name) VALUES ('credit_card'), ('paypal'), ('bank_transfer'), ('cash_on_delivery');

-- -------------------------
-- Core user / auth tables
-- -------------------------
CREATE TABLE users (
    user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Many-to-many: users <-> roles
CREATE TABLE user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id SMALLINT UNSIGNED NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -------------------------
-- Product catalog
-- -------------------------
CREATE TABLE categories (
    category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    parent_category_id INT UNSIGNED,
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(12,2) NOT NULL,
    weight_kg DECIMAL(6,3) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (price >= 0)
) ENGINE=InnoDB;

-- Product <-> Category (many-to-many)
CREATE TABLE product_categories (
    product_id BIGINT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, category_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Product images
CREATE TABLE product_images (
    image_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    url VARCHAR(1024) NOT NULL,
    alt_text VARCHAR(255),
    sort_order INT UNSIGNED DEFAULT 0,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Suppliers
CREATE TABLE suppliers (
    supplier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    UNIQUE (name)
) ENGINE=InnoDB;

-- Many-to-many: products <-> suppliers (with supplier SKU and cost)
CREATE TABLE product_suppliers (
    product_id BIGINT UNSIGNED NOT NULL,
    supplier_id INT UNSIGNED NOT NULL,
    supplier_sku VARCHAR(100),
    cost_price DECIMAL(12,2) NOT NULL DEFAULT 0,
    lead_time_days SMALLINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (product_id, supplier_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (cost_price >= 0)
) ENGINE=InnoDB;

-- Tags (and product_tags M2M)
CREATE TABLE tags (
    tag_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tag_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE product_tags (
    product_id BIGINT UNSIGNED NOT NULL,
    tag_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, tag_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Inventory (per product, optional per-warehouse extension possible)
CREATE TABLE inventory (
    product_id BIGINT UNSIGNED PRIMARY KEY,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    reserved INT UNSIGNED NOT NULL DEFAULT 0, -- e.g., reserved for pending orders
    reorder_threshold INT UNSIGNED DEFAULT 0,
    last_restock TIMESTAMP NULL,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    CHECK (quantity >= 0),
    CHECK (reserved >= 0)
) ENGINE=InnoDB;

-- -------------------------
-- Reviews (one-to-many: product <- reviews)
-- -------------------------
CREATE TABLE reviews (
    review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NULL,
    rating TINYINT UNSIGNED NOT NULL,
    title VARCHAR(255),
    body TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_approved TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- -------------------------
-- Addresses (one-to-many: user <- addresses)
-- -------------------------
CREATE TABLE addresses (
    address_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(100), -- e.g., "Home", "Office"
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(30),
    country VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    is_default_shipping TINYINT(1) NOT NULL DEFAULT 0,
    is_default_billing TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Ensure only one default per user for shipping and billing via indices & application logic (db-level enforcement of single default is complex)
CREATE INDEX idx_addresses_user_default_ship ON addresses(user_id, is_default_shipping);
CREATE INDEX idx_addresses_user_default_bill ON addresses(user_id, is_default_billing);

-- -------------------------
-- Shopping cart (guest or user) 
-- -------------------------
CREATE TABLE carts (
    cart_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    session_token VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE (session_token)
) ENGINE=InnoDB;

CREATE TABLE cart_items (
    cart_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cart_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cart_id) REFERENCES carts(cart_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    CHECK (quantity > 0)
) ENGINE=InnoDB;

-- -------------------------
-- Orders and order items
-- -------------------------
CREATE TABLE orders (
    order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NULL,
    order_number VARCHAR(50) NOT NULL UNIQUE, -- business facing ID e.g. ORD-20250924-0001
    status_id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    subtotal DECIMAL(12,2) NOT NULL,
    shipping DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount DECIMAL(12,2) NOT NULL DEFAULT 0,
    total DECIMAL(12,2) NOT NULL,
    billing_address_id BIGINT UNSIGNED NULL,
    shipping_address_id BIGINT UNSIGNED NULL,
    placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (status_id) REFERENCES order_status(status_id) ON DELETE RESTRICT,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL,
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL,
    CHECK (subtotal >= 0),
    CHECK (shipping >= 0),
    CHECK (tax >= 0),
    CHECK (discount >= 0),
    CHECK (total >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_items (
    order_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    sku VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    line_total DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    CHECK (unit_price >= 0),
    CHECK (quantity > 0),
    CHECK (line_total >= 0)
) ENGINE=InnoDB;

-- -------------------------
-- Payments (one-to-many: order <- payments)
-- -------------------------
CREATE TABLE payments (
    payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    payment_method_id SMALLINT UNSIGNED NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    provider_reference VARCHAR(255),
    paid_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(payment_method_id) ON DELETE RESTRICT,
    CHECK (amount >= 0)
) ENGINE=InnoDB;

-- -------------------------
-- Shipments / tracking
-- -------------------------
CREATE TABLE shipments (
    shipment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    shipped_at TIMESTAMP NULL,
    carrier VARCHAR(100),
    tracking_number VARCHAR(255),
    estimated_delivery DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'label_created',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -------------------------
-- Promotions / coupons
-- -------------------------
CREATE TABLE coupons (
    coupon_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    discount_type ENUM('percent','fixed') NOT NULL,
    discount_value DECIMAL(10,2) NOT NULL,
    max_uses INT UNSIGNED DEFAULT NULL,
    used_count INT UNSIGNED NOT NULL DEFAULT 0,
    valid_from DATE DEFAULT NULL,
    valid_to DATE DEFAULT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (discount_value >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_coupons (
    order_id BIGINT UNSIGNED NOT NULL,
    coupon_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (order_id, coupon_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (coupon_id) REFERENCES coupons(coupon_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- -------------------------
-- Audit / logs (simple)
-- -------------------------
CREATE TABLE audit_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    performed_by BIGINT UNSIGNED NULL,
    details JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (performed_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- -------------------------
-- Useful views (examples)
-- -------------------------
DROP VIEW IF EXISTS v_order_summary;
CREATE VIEW v_order_summary AS
SELECT
    o.order_id,
    o.order_number,
    o.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
    os.status_name,
    o.total,
    o.placed_at
FROM orders o
LEFT JOIN users u ON o.user_id = u.user_id
LEFT JOIN order_status os ON o.status_id = os.status_id;

-- -------------------------
-- Sample stored procedure (optional) - create order number
-- -------------------------
DROP PROCEDURE IF EXISTS gen_order_number;
DELIMITER $$
CREATE PROCEDURE gen_order_number(OUT out_order_number VARCHAR(50))
BEGIN
    -- Simple example: ORD-YYYYMMDD-<n>
    DECLARE seq_no INT;
    SET seq_no = (SELECT COALESCE(MAX(order_id), 0) + 1 FROM orders);
    SET out_order_number = CONCAT('ORD-', DATE_FORMAT(CURDATE(), '%Y%m%d'), '-', LPAD(seq_no,6,'0'));
END$$
DELIMITER ;

-- ==============================
-- Example: initial admin user (password hash placeholder)
-- ==============================
INSERT INTO users (email, password_hash, first_name, last_name, phone)
VALUES ('admin@example.com', '<hashed_password_here>', 'Site', 'Admin', '+000000000');

-- Give admin role to the admin user
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id FROM users u, roles r WHERE u.email='admin@example.com' AND r.role_name='admin';

-- ==============================
-- End of schema
-- ==============================
