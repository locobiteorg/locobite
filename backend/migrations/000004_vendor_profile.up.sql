-- Adds the columns needed for merchant-app auth and onboarding.
-- email is how vendors authenticate (same Supabase email-OTP flow as customers).
ALTER TABLE vendors
    ADD COLUMN IF NOT EXISTS email TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS owner_name TEXT,
    ADD COLUMN IF NOT EXISTS stall_image_url TEXT;
