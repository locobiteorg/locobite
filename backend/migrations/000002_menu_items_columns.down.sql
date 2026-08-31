ALTER TABLE menu_items
    DROP COLUMN IF EXISTS diet_type,
    DROP COLUMN IF EXISTS is_otc,
    DROP COLUMN IF EXISTS is_ten_min;
