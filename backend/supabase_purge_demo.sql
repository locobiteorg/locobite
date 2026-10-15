-- Removes ALL demo data (vendors/customers flagged is_demo, plus everything
-- that hangs off them). Real merchants and customers are untouched.
-- Run in the Supabase SQL editor when you're ready to go live.
--
-- STEP 1: run the SELECT below first and read the counts.
-- STEP 2: run the whole BEGIN ... COMMIT block.
--
-- NOTE: an order between a REAL customer and a DEMO vendor is also deleted
-- (the vendor it points to is going away).

-- ===== STEP 1: preview =====
-- select
--   (select count(*) from vendors   where is_demo) as demo_vendors,
--   (select count(*) from customers where is_demo) as demo_customers,
--   (select count(*) from orders where vendor_id in (select id from vendors where is_demo)
--       or customer_id in (select id from customers where is_demo)) as orders_to_delete;

-- ===== STEP 2: purge =====
BEGIN;

CREATE TEMP TABLE _dv ON COMMIT DROP AS SELECT id FROM vendors   WHERE is_demo;
CREATE TEMP TABLE _dc ON COMMIT DROP AS SELECT id FROM customers WHERE is_demo;
CREATE TEMP TABLE _do ON COMMIT DROP AS
  SELECT id FROM orders WHERE vendor_id IN (SELECT id FROM _dv) OR customer_id IN (SELECT id FROM _dc);
CREATE TEMP TABLE _dsales ON COMMIT DROP AS
  SELECT id FROM offline_sales WHERE vendor_id IN (SELECT id FROM _dv);

DELETE FROM payment_events  WHERE order_id IN (SELECT id FROM _do) OR offline_sale_id IN (SELECT id FROM _dsales);
DELETE FROM vendor_disputes WHERE vendor_id IN (SELECT id FROM _dv)
   OR dispute_id IN (SELECT id FROM disputes WHERE order_id IN (SELECT id FROM _do));
DELETE FROM disputes        WHERE order_id IN (SELECT id FROM _do);
DELETE FROM vendor_penalties WHERE vendor_id IN (SELECT id FROM _dv) OR order_id IN (SELECT id FROM _do);
DELETE FROM customer_dues_ledger WHERE customer_id IN (SELECT id FROM _dc) OR applied_to_order_id IN (SELECT id FROM _do);
DELETE FROM order_items     WHERE order_id IN (SELECT id FROM _do);
DELETE FROM orders          WHERE id IN (SELECT id FROM _do);
DELETE FROM offline_sales   WHERE id IN (SELECT id FROM _dsales);
DELETE FROM delivery_partners WHERE vendor_id IN (SELECT id FROM _dv);
DELETE FROM vendor_taps     WHERE vendor_id IN (SELECT id FROM _dv) OR customer_id IN (SELECT id FROM _dc);
DELETE FROM menu_items      WHERE vendor_id IN (SELECT id FROM _dv);
DELETE FROM dish_images     WHERE submitted_by_vendor_id IN (SELECT id FROM _dv);
DELETE FROM vendors         WHERE id IN (SELECT id FROM _dv);
DELETE FROM customers       WHERE id IN (SELECT id FROM _dc);

COMMIT;
