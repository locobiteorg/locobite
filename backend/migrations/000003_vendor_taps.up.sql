CREATE TABLE vendor_taps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vendor_taps_vendor_id ON vendor_taps (vendor_id);
CREATE INDEX idx_vendor_taps_customer_id ON vendor_taps (customer_id);
