ALTER TABLE payment_events DROP CONSTRAINT IF EXISTS payment_events_source_chk;
ALTER TABLE payment_events DROP CONSTRAINT IF EXISTS payment_events_offline_sale_fk;

DROP TABLE IF EXISTS offline_sales;
DROP TABLE IF EXISTS delivery_partners;
DROP TABLE IF EXISTS customer_dues_ledger;
DROP TABLE IF EXISTS vendor_penalties;
DROP TABLE IF EXISTS vendor_disputes;
DROP TABLE IF EXISTS disputes;
DROP TABLE IF EXISTS payment_events;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS vendors;
DROP TABLE IF EXISTS customers;

DROP TYPE IF EXISTS diet_type;
DROP TYPE IF EXISTS dues_ledger_status;
DROP TYPE IF EXISTS dispute_status;
DROP TYPE IF EXISTS dispute_type;
DROP TYPE IF EXISTS payment_event_type;
DROP TYPE IF EXISTS pickup_status;
DROP TYPE IF EXISTS rejection_reason;
DROP TYPE IF EXISTS order_status;
DROP TYPE IF EXISTS vendor_accept_mode;
DROP TYPE IF EXISTS subscription_tier;
