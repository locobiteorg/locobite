DROP INDEX IF EXISTS uq_dish_images_dish_url;
ALTER TABLE dish_images DROP COLUMN IF EXISTS is_placeholder;
ALTER TABLE customers   DROP COLUMN IF EXISTS is_demo;
ALTER TABLE vendors     DROP COLUMN IF EXISTS is_demo;
