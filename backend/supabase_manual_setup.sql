-- Locobite merchant setup. Assumes migrations 000001-000003 already exist. Safe to re-run.

-- ===== 1. Vendor profile columns =====
-- Adds the columns needed for merchant-app auth and onboarding.
-- email is how vendors authenticate (same Supabase email-OTP flow as customers).
ALTER TABLE vendors
    ADD COLUMN IF NOT EXISTS email TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS owner_name TEXT,
    ADD COLUMN IF NOT EXISTS stall_image_url TEXT;

-- ===== 2. Dish image library =====
-- Shared, tagged dish image library so merchants don't have to photograph
-- every item to onboard. Matching works across languages via dish_synonyms.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS dish_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dish_synonyms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dish_id UUID NOT NULL REFERENCES dish_catalog (id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    language_code TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (dish_id, display_name, language_code)
);

-- Fuzzy matching across languages/spellings: GIN + pg_trgm on normalized_name.
CREATE INDEX IF NOT EXISTS idx_dish_synonyms_normalized_trgm ON dish_synonyms USING GIN (normalized_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_dish_synonyms_dish_id ON dish_synonyms (dish_id);

DO $$ BEGIN CREATE TYPE dish_image_source AS ENUM ('stock', 'vendor_submitted'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE dish_image_status AS ENUM ('approved', 'pending_review', 'rejected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS dish_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dish_id UUID NOT NULL REFERENCES dish_catalog (id) ON DELETE CASCADE,
    image_url TEXT NOT NULL, -- CDN/Storage URL only; never raw bytes in Postgres.
    source dish_image_source NOT NULL DEFAULT 'stock',
    status dish_image_status NOT NULL DEFAULT 'pending_review',
    sort_order INTEGER NOT NULL DEFAULT 0,
    submitted_by_vendor_id UUID REFERENCES vendors (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dish_images_dish_status ON dish_images (dish_id, status);

-- Link menu_items to the catalog so re-resolution isn't needed on every read.
ALTER TABLE menu_items
    ADD COLUMN IF NOT EXISTS dish_id UUID REFERENCES dish_catalog (id),
    ADD COLUMN IF NOT EXISTS selected_image_id UUID REFERENCES dish_images (id),
    ADD COLUMN IF NOT EXISTS image_source_note TEXT,
    ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT TRUE;

-- ===== 3. Seed dishes =====
-- Seeds ~18 common railway-station dishes with English/Hindi/one regional
-- synonym each, plus placeholder stock images, so resolve()/search() have
-- data to match against immediately. Image URLs are placeholders — swap
-- for real CDN/Storage URLs before relying on them in a UI.

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('samosa') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Samosa', 'en'), ('समोसा', 'hi'), ('Singara', 'bn')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/samosa-1.jpg'), (2, 'https://cdn.locobite.app/dishes/samosa-2.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('pav-bhaji') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Pav Bhaji', 'en'), ('पाव भाजी', 'hi'), ('Pav Bhaji', 'mr')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/pav-bhaji-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('vada-pav') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Vada Pav', 'en'), ('वड़ा पाव', 'hi'), ('Vada Pav', 'mr')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/vada-pav-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('chai') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Chai', 'en'), ('चाय', 'hi'), ('Cha', 'bn'), ('Tea', 'en')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/chai-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('sandwich') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Sandwich', 'en'), ('सैंडविच', 'hi')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/sandwich-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('poha') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Poha', 'en'), ('पोहा', 'hi'), ('Avalakki', 'kn')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/poha-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('idli') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Idli', 'en'), ('इडली', 'hi'), ('இட்லி', 'ta')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/idli-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('dosa') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Dosa', 'en'), ('डोसा', 'hi'), ('தோசை', 'ta')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/dosa-1.jpg'), (2, 'https://cdn.locobite.app/dishes/dosa-2.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('vada') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Vada', 'en'), ('वड़ा', 'hi'), ('வடை', 'ta')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/vada-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('upma') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Upma', 'en'), ('उपमा', 'hi'), ('உப்புமா', 'ta')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/upma-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('biryani') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Biryani', 'en'), ('बिरयानी', 'hi'), ('బిర్యానీ', 'te')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/biryani-1.jpg'), (2, 'https://cdn.locobite.app/dishes/biryani-2.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('paneer-tikka') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Paneer Tikka', 'en'), ('पनीर टिक्का', 'hi')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/paneer-tikka-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('aloo-paratha') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Aloo Paratha', 'en'), ('आलू पराठा', 'hi'), ('Alu Parantha', 'pa')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/aloo-paratha-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('chole-bhature') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Chole Bhature', 'en'), ('छोले भटूरे', 'hi')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/chole-bhature-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('dhokla') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Dhokla', 'en'), ('ढोकला', 'hi'), ('Dhokla', 'gu')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/dhokla-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('kachori') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Kachori', 'en'), ('कचौरी', 'hi')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/kachori-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('jalebi') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Jalebi', 'en'), ('जलेबी', 'hi')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/jalebi-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('lassi') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Lassi', 'en'), ('लस्सी', 'hi'), ('Lassi', 'pa')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/lassi-1.jpg')) AS v(ord, u)
) SELECT 1;

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('misal-pav') ON CONFLICT (canonical_slug) DO NOTHING RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Misal Pav', 'en'), ('मिसळ पाव', 'hi'), ('Misal Pav', 'mr')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/misal-pav-1.jpg')) AS v(ord, u)
) SELECT 1;

-- ===== 4. Lock down new/PII tables (Go server uses the postgres role, which bypasses RLS) =====
ALTER TABLE vendors      ENABLE ROW LEVEL SECURITY;
ALTER TABLE dish_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE dish_synonyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE dish_images  ENABLE ROW LEVEL SECURITY;

-- ===== 5. Storage buckets + policies =====
INSERT INTO storage.buckets (id, name, public) VALUES
  ('stall-images','stall-images', true),
  ('dish-images','dish-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "public read merchant images" ON storage.objects;
DROP POLICY IF EXISTS "signed-in upload merchant images" ON storage.objects;
DROP POLICY IF EXISTS "signed-in update merchant images" ON storage.objects;
CREATE POLICY "public read merchant images" ON storage.objects
  FOR SELECT USING (bucket_id IN ('stall-images','dish-images'));
CREATE POLICY "signed-in upload merchant images" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id IN ('stall-images','dish-images'));
CREATE POLICY "signed-in update merchant images" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id IN ('stall-images','dish-images'));
