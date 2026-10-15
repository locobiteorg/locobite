-- Run once in the Supabase SQL editor (safe to re-run).
-- Adds demo flags + the placeholder flag, and locks the stock-image folder.

ALTER TABLE vendors     ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE customers   ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE dish_images ADD COLUMN IF NOT EXISTS is_placeholder BOOLEAN NOT NULL DEFAULT FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_dish_images_dish_url ON dish_images (dish_id, image_url);

UPDATE vendors SET is_demo = TRUE WHERE id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    '77777777-7777-7777-7777-777777777777',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '10101010-1010-1010-1010-101010101010',
    '14141414-1414-1414-1414-141414141414',
    '15151515-1515-1515-1515-151515151515',
    '16161616-1616-1616-1616-161616161616'
);
UPDATE customers SET is_demo = TRUE WHERE id = '99999999-9999-9999-9999-999999999999';
UPDATE dish_images SET is_placeholder = TRUE WHERE image_url LIKE 'https://cdn.locobite.app/%';

-- Storage: merchants may add photos but must not overwrite or replace the
-- curated stock library, and only stall photos need overwrite (upsert).
DROP POLICY IF EXISTS "signed-in upload merchant images" ON storage.objects;
DROP POLICY IF EXISTS "signed-in update merchant images" ON storage.objects;
CREATE POLICY "signed-in upload merchant images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('stall-images','dish-images')
    AND NOT (bucket_id = 'dish-images' AND (storage.foldername(name))[1] = 'stock')
  );
DROP POLICY IF EXISTS "signed-in update stall images" ON storage.objects;
CREATE POLICY "signed-in update stall images" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'stall-images');
