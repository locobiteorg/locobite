-- Shared, tagged dish image library so merchants don't have to photograph
-- every item to onboard. Matching works across languages via dish_synonyms.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE dish_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dish_synonyms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dish_id UUID NOT NULL REFERENCES dish_catalog (id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    language_code TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (dish_id, display_name, language_code)
);

-- Fuzzy matching across languages/spellings: GIN + pg_trgm on normalized_name.
CREATE INDEX idx_dish_synonyms_normalized_trgm ON dish_synonyms USING GIN (normalized_name gin_trgm_ops);
CREATE INDEX idx_dish_synonyms_dish_id ON dish_synonyms (dish_id);

CREATE TYPE dish_image_source AS ENUM ('stock', 'vendor_submitted');
CREATE TYPE dish_image_status AS ENUM ('approved', 'pending_review', 'rejected');

CREATE TABLE dish_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dish_id UUID NOT NULL REFERENCES dish_catalog (id) ON DELETE CASCADE,
    image_url TEXT NOT NULL, -- CDN/Storage URL only; never raw bytes in Postgres.
    source dish_image_source NOT NULL DEFAULT 'stock',
    status dish_image_status NOT NULL DEFAULT 'pending_review',
    sort_order INTEGER NOT NULL DEFAULT 0,
    submitted_by_vendor_id UUID REFERENCES vendors (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_dish_images_dish_status ON dish_images (dish_id, status);

-- Link menu_items to the catalog so re-resolution isn't needed on every read.
ALTER TABLE menu_items
    ADD COLUMN IF NOT EXISTS dish_id UUID REFERENCES dish_catalog (id),
    ADD COLUMN IF NOT EXISTS selected_image_id UUID REFERENCES dish_images (id),
    ADD COLUMN IF NOT EXISTS image_source_note TEXT,
    ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT TRUE;
