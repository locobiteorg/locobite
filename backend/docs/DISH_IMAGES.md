# Dish images: how they work, and how to add real ones

## How the pieces fit
- `dish_catalog` — one row per dish (`samosa`, `pav-bhaji`, …).
- `dish_synonyms` — every name a dish goes by, per language. This is what the
  merchant's typed name (or Gemini's extracted name) is matched against.
- `dish_images` — photos per dish. `is_placeholder = true` marks the fake seed
  URLs; real ones are `false`. Vendor photos arrive as `vendor_submitted` /
  `pending_review` and are only shown to other merchants once you approve them.
- A merchant's menu item stores `dish_id` + `selected_image_id`; the customer
  app shows that image. So **replacing a photo in the library updates every
  menu that uses it** — nobody has to re-pick.

The photos themselves live in Supabase Storage, never in Postgres.

## One-time setup
1. Supabase → Storage: the `dish-images` bucket exists (public) after running
   `supabase_manual_setup.sql`. Create a folder named `stock/` in it.
2. Run `supabase_update_000007.sql` (adds the placeholder flag, the unique
   index the importer relies on, and locks `stock/` so merchants can't
   overwrite your photos).

## Adding or replacing photos (repeatable, no code changes)
1. **Prepare images:** one dish per file, square-ish, ≥ 800×800, JPG/WebP,
   under ~300 KB. Name them `<slug>-1.jpg`, `<slug>-2.jpg` (e.g. `samosa-1.jpg`).
2. **Upload** them to Storage → `dish-images` → `stock/` (drag and drop).
3. **Describe them** in a manifest (copy `dishes.example.json`):
   ```json
   { "base_url": "https://<project-ref>.supabase.co/storage/v1/object/public/dish-images/stock",
     "dishes": [ { "slug": "samosa",
                   "synonyms": [ {"name":"Samosa","lang":"en"}, {"name":"समोसा","lang":"hi"} ],
                   "images": ["samosa-1.jpg", "samosa-2.jpg"] } ] }
   ```
   A new dish is just a new entry (new slug, its names, its files).
4. **Preview, then apply** (needs `DATABASE_URL`):
   ```bash
   cd backend
   go run ./cmd/dishimages -manifest dishes.json -dry-run
   go run ./cmd/dishimages -manifest dishes.json
   ```
   It is safe to re-run. When a dish gets its first real photo, its placeholder
   rows are removed and any menu item that pointed at one is re-pointed to the
   new top photo.

## Reviewing merchant-submitted photos
```sql
-- what's waiting
select i.id, c.canonical_slug, i.image_url, v.name as submitted_by
from dish_images i join dish_catalog c on c.id=i.dish_id
left join vendors v on v.id=i.submitted_by_vendor_id
where i.status='pending_review';
-- approve / reject
update dish_images set status='approved' where id='<id>';
update dish_images set status='rejected' where id='<id>';
```

## Going live: removing the dummy data
1. Run the preview `select` at the top of `supabase_purge_demo.sql`.
2. Run the `BEGIN … COMMIT` block. Removes every vendor/customer flagged
   `is_demo`, their orders, menus and dues. Real data is untouched.
3. Re-run `dishimages` for any dish that still shows a placeholder:
   `select c.canonical_slug from dish_images i join dish_catalog c on c.id=i.dish_id where i.is_placeholder;`
