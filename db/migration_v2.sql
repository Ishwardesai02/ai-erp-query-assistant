-- ============================================================
--  MIGRATION V2: Product Market Info Table (fixed column names)
-- ============================================================

DROP VIEW  IF EXISTS v_products_with_market CASCADE;
DROP TABLE IF EXISTS product_market_info CASCADE;

CREATE TABLE product_market_info (
    info_id           SERIAL PRIMARY KEY,
    product_id        INT UNIQUE NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    market_price_min  NUMERIC(12,2),
    market_price_max  NUMERIC(12,2),
    market_price_avg  NUMERIC(12,2),
    currency          VARCHAR(5) DEFAULT 'INR',
    availability      VARCHAR(50),
    supplier_name     VARCHAR(200),
    supplier_url      TEXT,
    product_url       TEXT,
    specifications    JSONB DEFAULT '{}',
    scraped_from      VARCHAR(200),
    scrape_status     VARCHAR(20) DEFAULT 'pending'
                      CHECK (scrape_status IN ('pending','success','failed','blocked','manual')),
    scrape_error      TEXT,
    last_scraped_at   TIMESTAMP,
    created_at        TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_pmi_product    ON product_market_info(product_id);
CREATE INDEX idx_pmi_status     ON product_market_info(scrape_status);
CREATE INDEX idx_pmi_scraped_at ON product_market_info(last_scraped_at);

-- ============================================================
--  View: all column names explicit and correct
-- ============================================================
CREATE OR REPLACE VIEW v_products_with_market AS
SELECT
    p.product_id,
    p.sku,
    p.name                  AS product_name,
    p.unit_price            AS erp_unit_price,
    p.cost_price            AS erp_cost_price,
    p.qty_in_stock,
    p.reorder_level,
    pc.name                 AS category,
    pmi.market_price_min,
    pmi.market_price_max,
    pmi.market_price_avg,
    pmi.availability        AS market_availability,
    pmi.supplier_name       AS market_supplier,
    pmi.product_url,
    pmi.specifications,
    pmi.scraped_from,
    pmi.scrape_status,
    pmi.last_scraped_at
FROM products p
LEFT JOIN product_categories pc   ON p.category_id  = pc.category_id
LEFT JOIN product_market_info pmi ON p.product_id   = pmi.product_id;
