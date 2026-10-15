ALTER TABLE vendors
    DROP COLUMN IF EXISTS stall_image_url,
    DROP COLUMN IF EXISTS owner_name,
    DROP COLUMN IF EXISTS email;
