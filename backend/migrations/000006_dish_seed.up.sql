-- Seeds ~18 common railway-station dishes with English/Hindi/one regional
-- synonym each, plus placeholder stock images, so resolve()/search() have
-- data to match against immediately. Image URLs are placeholders — swap
-- for real CDN/Storage URLs before relying on them in a UI.

WITH d AS (
    INSERT INTO dish_catalog (canonical_slug) VALUES ('samosa') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('pav-bhaji') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('vada-pav') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('chai') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('sandwich') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('poha') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('idli') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('dosa') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('vada') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('upma') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('biryani') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('paneer-tikka') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('aloo-paratha') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('chole-bhature') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('dhokla') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('kachori') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('jalebi') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('lassi') RETURNING id
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
    INSERT INTO dish_catalog (canonical_slug) VALUES ('misal-pav') RETURNING id
), syn AS (
    INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
    SELECT id, v.display_name, v.language_code, lower(trim(v.display_name))
    FROM d, (VALUES ('Misal Pav', 'en'), ('मिसळ पाव', 'hi'), ('Misal Pav', 'mr')) AS v(display_name, language_code)
), img AS (
    INSERT INTO dish_images (dish_id, image_url, source, status, sort_order)
    SELECT id, u, 'stock', 'approved', ord
    FROM d, (VALUES (1, 'https://cdn.locobite.app/dishes/misal-pav-1.jpg')) AS v(ord, u)
) SELECT 1;
