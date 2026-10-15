-- Makes dummy data identifiable and removable, and gives the dish library a
-- safe path from placeholder images to real ones.
ALTER TABLE vendors     ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE customers   ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE dish_images ADD COLUMN IF NOT EXISTS is_placeholder BOOLEAN NOT NULL DEFAULT FALSE;

-- One row per (dish, url) so re-running an image import never duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS uq_dish_images_dish_url ON dish_images (dish_id, image_url);

-- Flag what cmd/seed and migration 000006 created.
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
