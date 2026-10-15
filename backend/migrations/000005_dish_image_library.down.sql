ALTER TABLE menu_items
    DROP COLUMN IF EXISTS is_available,
    DROP COLUMN IF EXISTS image_source_note,
    DROP COLUMN IF EXISTS selected_image_id,
    DROP COLUMN IF EXISTS dish_id;

DROP TABLE IF EXISTS dish_images;
DROP TYPE IF EXISTS dish_image_status;
DROP TYPE IF EXISTS dish_image_source;
DROP TABLE IF EXISTS dish_synonyms;
DROP TABLE IF EXISTS dish_catalog;
