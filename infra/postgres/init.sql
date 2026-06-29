-- ============================================================
-- Biashara Copilot — PostgreSQL Schema
-- Multi-tenant, event-ready, Kenya SME domain model
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ■■■ Tenants (businesses) ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    business_type VARCHAR(50) DEFAULT 'retail', -- retail|wholesale|pharmacy|agrovet|salon
    country VARCHAR(3) DEFAULT 'KE',
    currency VARCHAR(3) DEFAULT 'KES',
    phone VARCHAR(20),
    email VARCHAR(200),
    address TEXT,
    logo_url TEXT,
    plan VARCHAR(20) DEFAULT 'free', -- free|starter|pro
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Branches (per tenant) ■■■■■■■■■■■■■■■─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    location VARCHAR(300),
    phone VARCHAR(20),
    is_main BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Users ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id),
    email VARCHAR(200) NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(200) NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) DEFAULT 'staff', -- owner|manager|staff|accountant
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

-- ■■■ Product Categories ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    parent_id UUID REFERENCES categories(id),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Products / SKUs ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    sku VARCHAR(100),
    name VARCHAR(300) NOT NULL,
    description TEXT,
    unit VARCHAR(30) DEFAULT 'piece', -- piece|kg|litre|pack|dozen
    cost_price NUMERIC(14,2) DEFAULT 0,
    selling_price NUMERIC(14,2) DEFAULT 0,
    tax_rate NUMERIC(5,2) DEFAULT 0,
    barcode VARCHAR(100),
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    track_stock BOOLEAN DEFAULT TRUE,
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, sku)
);

-- ■■■ Stock (per branch) ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE stock (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity NUMERIC(14,3) DEFAULT 0,
    reorder_level NUMERIC(14,3) DEFAULT 5, -- trigger stock_low alert
    reorder_qty NUMERIC(14,3) DEFAULT 20,  -- AI-suggested reorder qty
    last_restock_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(branch_id, product_id)
);

-- ■■■ Stock Movements (full audit trail) ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id),
    product_id UUID NOT NULL REFERENCES products(id),
    movement_type VARCHAR(20) NOT NULL, -- sale|purchase|adjustment|transfer|return
    quantity NUMERIC(14,3) NOT NULL,    -- positive=in, negative=out
    unit_cost NUMERIC(14,2),
    reference_id UUID,                  -- sale_id | purchase_id
    reference_type VARCHAR(30),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Suppliers ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    contact_name VARCHAR(200),
    phone VARCHAR(20),
    email VARCHAR(200),
    address TEXT,
    payment_terms INTEGER DEFAULT 30, -- days
    credit_limit NUMERIC(14,2) DEFAULT 0,
    balance_owed NUMERIC(14,2) DEFAULT 0,
    rating NUMERIC(3,2) DEFAULT 5.0,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Customers ■■■■■■■■----------━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─━─
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(200),
    address TEXT,
    credit_limit NUMERIC(14,2) DEFAULT 0,
    balance_owed NUMERIC(14,2) DEFAULT 0,
    total_purchases NUMERIC(14,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Sales Orders ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id),
    customer_id UUID REFERENCES customers(id),
    created_by UUID REFERENCES users(id),
    sale_number VARCHAR(50),
    subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(14,2) DEFAULT 0,
    discount NUMERIC(14,2) DEFAULT 0,
    total NUMERIC(14,2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(14,2) DEFAULT 0,
    payment_method VARCHAR(30) DEFAULT 'cash', -- cash|mpesa|credit|card|bank
    payment_ref VARCHAR(100),                  -- M-Pesa confirmation code
    status VARCHAR(20) DEFAULT 'completed',    -- draft|completed|voided|refunded
    notes TEXT,
    source VARCHAR(20) DEFAULT 'pos',          -- pos|whatsapp|csv_import
    sale_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    quantity NUMERIC(14,3) NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    cost_price NUMERIC(14,2),
    discount NUMERIC(14,2) DEFAULT 0,
    total NUMERIC(14,2) NOT NULL
);

-- ■■■ Purchases / Stock Intake ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id),
    supplier_id UUID REFERENCES suppliers(id),
    created_by UUID REFERENCES users(id),
    invoice_number VARCHAR(100),
    subtotal NUMERIC(14,2) DEFAULT 0,
    tax_amount NUMERIC(14,2) DEFAULT 0,
    total NUMERIC(14,2) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(14,2) DEFAULT 0,
    due_amount NUMERIC(14,2) DEFAULT 0,
    payment_status VARCHAR(20) DEFAULT 'unpaid', -- unpaid|partial|paid|overdue
    due_date DATE,
    status VARCHAR(20) DEFAULT 'received',
    notes TEXT,
    receipt_url TEXT, -- S3 path to scanned receipt
    purchase_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    quantity NUMERIC(14,3) NOT NULL,
    unit_cost NUMERIC(14,2) NOT NULL,
    total NUMERIC(14,2) NOT NULL
);

-- ■■■ Expenses ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE expense_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    is_system BOOLEAN DEFAULT FALSE
);

CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id),
    category_id UUID REFERENCES expense_categories(id),
    created_by UUID REFERENCES users(id),
    description VARCHAR(500) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    payment_method VARCHAR(30) DEFAULT 'cash',
    receipt_url TEXT,
    is_anomaly BOOLEAN DEFAULT FALSE,
    anomaly_note TEXT,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Receipts (OCR pipeline) ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id),
    uploaded_by UUID REFERENCES users(id),
    file_url TEXT NOT NULL,
    file_name VARCHAR(300),
    ocr_status VARCHAR(20) DEFAULT 'pending', -- pending|processing|done|failed
    ocr_raw JSONB,
    extracted_data JSONB, -- parsed vendor, items, total, date
    linked_to_type VARCHAR(20), -- purchase|expense
    linked_to_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

-- ■■■ AI Insights & Summaries ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE ai_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id),
    summary_type VARCHAR(30) NOT NULL, -- weekly|daily|alert|cashflow|stockout
    period_start DATE,
    period_end DATE,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    provider VARCHAR(30), -- anthropic|openai|gemini|huggingface
    model VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Forecasts ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE forecasts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id),
    product_id UUID REFERENCES products(id),
    forecast_type VARCHAR(20) NOT NULL, -- demand|cashflow|stockout
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    predicted_value NUMERIC(14,3),
    confidence NUMERIC(5,3),
    model_used VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Alerts ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id),
    alert_type VARCHAR(30) NOT NULL, -- stock_low|payment_overdue|margin_drop|anomaly
    severity VARCHAR(10) DEFAULT 'medium', -- low|medium|high|critical
    title VARCHAR(300) NOT NULL,
    body TEXT,
    entity_type VARCHAR(30), -- product|supplier|expense
    entity_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    is_dismissed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Audit Logs ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ■■■ Indexes ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE INDEX idx_products_tenant ON products(tenant_id);
CREATE INDEX idx_products_name_trgm ON products USING gin(name gin_trgm_ops);
CREATE INDEX idx_stock_tenant_branch ON stock(tenant_id, branch_id);
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id, created_at DESC);
CREATE INDEX idx_sales_tenant_date ON sales(tenant_id, sale_date DESC);
CREATE INDEX idx_sales_branch_date ON sales(branch_id, sale_date DESC);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);
CREATE INDEX idx_expenses_tenant_date ON expenses(tenant_id, expense_date DESC);
CREATE INDEX idx_alerts_tenant_unread ON alerts(tenant_id, is_read, created_at DESC);
CREATE INDEX idx_receipts_tenant_status ON receipts(tenant_id, ocr_status);
CREATE INDEX idx_audit_tenant ON audit_logs(tenant_id, created_at DESC);

-- ■■■ Updated_at trigger ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN 
    NEW.updated_at = NOW(); 
    RETURN NEW; 
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_stock_updated_at BEFORE UPDATE ON stock FOR EACH ROW EXECUTE FUNCTION update_updated_at();