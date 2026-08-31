CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enums
CREATE TYPE subscription_tier AS ENUM ('level_1', 'level_2', 'level_3');
CREATE TYPE vendor_accept_mode AS ENUM ('accept_all', 'manual');
CREATE TYPE order_status AS ENUM (
    'requested',
    'accepted',
    'preparing',
    'ready',
    'out_for_delivery',
    'delivered',
    'cancelled',
    'rejected',
    'disputed',
    'refunded'
);
CREATE TYPE rejection_reason AS ENUM ('out_of_stock', 'too_busy', 'closing_soon', 'other');
CREATE TYPE pickup_status AS ENUM ('pending', 'collected', 'not_collected');
CREATE TYPE payment_event_type AS ENUM ('qr_generated', 'upi_confirmed', 'cash_confirmed');
CREATE TYPE dispute_type AS ENUM ('not_collected', 'customer_not_at_seat');
CREATE TYPE dispute_status AS ENUM ('open', 'resolved_refunded', 'resolved_rejected');
CREATE TYPE dues_ledger_status AS ENUM ('pending', 'applied', 'cleared');
CREATE TYPE diet_type AS ENUM ('veg', 'non_veg');

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    dues_balance_paise INTEGER NOT NULL DEFAULT 0,
    is_blocked_for_dues BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    station_code TEXT NOT NULL,
    subscription_tier subscription_tier NOT NULL,
    fssai_status TEXT NOT NULL DEFAULT 'unknown',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    accept_mode vendor_accept_mode NOT NULL DEFAULT 'manual'
);

CREATE INDEX idx_vendors_station_code ON vendors (station_code);
CREATE INDEX idx_vendors_is_active ON vendors (is_active);

-- Stub of the Supabase discovery table so local migrations/seed can run.
-- Production already has this table; IF NOT EXISTS keeps this idempotent.
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    name TEXT NOT NULL,
    price_paise INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    status order_status NOT NULL DEFAULT 'requested',
    amount_paise INTEGER NOT NULL,
    train_number TEXT NOT NULL,
    direction TEXT NOT NULL,
    seat_coach TEXT NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    delay_updated_at TIMESTAMPTZ,
    rejection_reason rejection_reason,
    pickup_status pickup_status NOT NULL DEFAULT 'pending',
    has_ten_min_item BOOLEAN NOT NULL DEFAULT FALSE,
    payment_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_vendor_id ON orders (vendor_id);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_created_at ON orders (created_at);

-- Line items are required to compute amount_paise, validate menu items, and reorder.
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders (id),
    menu_item_id UUID NOT NULL REFERENCES menu_items (id),
    name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_paise INTEGER NOT NULL,
    is_ten_min BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_order_items_order_id ON order_items (order_id);

CREATE TABLE payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders (id),
    offline_sale_id UUID,
    type payment_event_type NOT NULL,
    qr_generated_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    amount_paise INTEGER NOT NULL,
    raw_webhook_payload JSONB,
    provider_event_id TEXT UNIQUE,
    provider_ref TEXT
);

CREATE INDEX idx_payment_events_order_id ON payment_events (order_id);

CREATE TABLE disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders (id),
    customer_id UUID NOT NULL REFERENCES customers (id),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    type dispute_type NOT NULL,
    status dispute_status NOT NULL DEFAULT 'open',
    refund_tier_paise INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_disputes_order_id ON disputes (order_id);
CREATE INDEX idx_disputes_customer_id_created_at ON disputes (customer_id, created_at);
CREATE INDEX idx_disputes_vendor_id_created_at ON disputes (vendor_id, created_at);

CREATE TABLE vendor_disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    dispute_id UUID NOT NULL REFERENCES disputes (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vendor_disputes_vendor_created ON vendor_disputes (vendor_id, created_at);

CREATE TABLE vendor_penalties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    order_id UUID NOT NULL REFERENCES orders (id),
    reason rejection_reason NOT NULL,
    amount_paise INTEGER NOT NULL,
    customer_share_paise INTEGER NOT NULL,
    platform_share_paise INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vendor_penalties_vendor_created ON vendor_penalties (vendor_id, created_at);

CREATE TABLE customer_dues_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers (id),
    amount_paise INTEGER NOT NULL,
    reason TEXT NOT NULL,
    applied_to_order_id UUID REFERENCES orders (id),
    status dues_ledger_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_dues_ledger_customer_status ON customer_dues_ledger (customer_id, status, created_at);

CREATE TABLE delivery_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE offline_sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES vendors (id),
    amount_paise INTEGER NOT NULL,
    qr_generated_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    payment_verified BOOLEAN NOT NULL DEFAULT FALSE,
    provider_ref TEXT
);

CREATE INDEX idx_offline_sales_vendor_id ON offline_sales (vendor_id);

ALTER TABLE payment_events
    ADD CONSTRAINT payment_events_offline_sale_fk
    FOREIGN KEY (offline_sale_id) REFERENCES offline_sales (id);

ALTER TABLE payment_events
    ADD CONSTRAINT payment_events_source_chk
    CHECK (
        (order_id IS NOT NULL AND offline_sale_id IS NULL)
        OR (order_id IS NULL AND offline_sale_id IS NOT NULL)
        OR (order_id IS NULL AND offline_sale_id IS NULL)
    );
