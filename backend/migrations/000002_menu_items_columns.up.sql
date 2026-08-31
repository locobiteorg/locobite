-- Adds Go-service columns onto the Supabase discovery menu_items table.
ALTER TABLE menu_items
    ADD COLUMN IF NOT EXISTS diet_type diet_type NOT NULL DEFAULT 'veg',
    ADD COLUMN IF NOT EXISTS is_otc BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_ten_min BOOLEAN NOT NULL DEFAULT FALSE;
