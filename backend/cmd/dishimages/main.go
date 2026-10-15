// dishimages loads real dish photos (and any new dishes/synonyms) into the
// shared dish library from a JSON manifest. It is idempotent: re-running
// with the same manifest changes nothing, and adding a dish or image is
// just another entry in the file — no code or migration needed.
//
//	go run ./cmd/dishimages -manifest dishes.json            # apply
//	go run ./cmd/dishimages -manifest dishes.json -dry-run   # preview only
//
// When a dish gets its first real image, the placeholder images for that
// dish are retired and any menu item still pointing at a placeholder is
// re-pointed to the new top image, so nothing is left dangling.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type synonym struct {
	Name string `json:"name"`
	Lang string `json:"lang"`
}

type dish struct {
	Slug     string    `json:"slug"`
	Synonyms []synonym `json:"synonyms"`
	// Images are absolute URLs, or file names joined onto base_url.
	Images []string `json:"images"`
}

type manifest struct {
	BaseURL string `json:"base_url"`
	Dishes  []dish `json:"dishes"`
}

func main() {
	path := flag.String("manifest", "", "path to the JSON manifest")
	dry := flag.Bool("dry-run", false, "print what would change, write nothing")
	flag.Parse()
	if *path == "" {
		log.Fatal("-manifest is required")
	}
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		log.Fatal("DATABASE_URL is required")
	}
	raw, err := os.ReadFile(*path)
	if err != nil {
		log.Fatal(err)
	}
	var m manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		log.Fatalf("invalid manifest: %v", err)
	}
	for _, d := range m.Dishes {
		if strings.TrimSpace(d.Slug) == "" {
			log.Fatal("every dish needs a slug")
		}
		for _, img := range d.Images {
			if !strings.HasPrefix(img, "http") && m.BaseURL == "" {
				log.Fatalf("dish %q: image %q is not a URL and the manifest has no base_url", d.Slug, img)
			}
		}
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()
	tx, err := pool.Begin(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer tx.Rollback(ctx)

	var newDishes, newSyns, newImgs, retired, repointed int
	for _, d := range m.Dishes {
		var dishID string
		err := tx.QueryRow(ctx, `SELECT id FROM dish_catalog WHERE canonical_slug = $1`, d.Slug).Scan(&dishID)
		if err == pgx.ErrNoRows {
			if err := tx.QueryRow(ctx, `INSERT INTO dish_catalog (canonical_slug) VALUES ($1) RETURNING id`, d.Slug).Scan(&dishID); err != nil {
				log.Fatalf("dish %s: %v", d.Slug, err)
			}
			newDishes++
		} else if err != nil {
			log.Fatalf("dish %s: %v", d.Slug, err)
		}

		for _, s := range d.Synonyms {
			tag, err := tx.Exec(ctx, `
				INSERT INTO dish_synonyms (dish_id, display_name, language_code, normalized_name)
				VALUES ($1, $2, $3, lower(trim($2)))
				ON CONFLICT (dish_id, display_name, language_code) DO NOTHING
			`, dishID, s.Name, s.Lang)
			if err != nil {
				log.Fatalf("synonym %q: %v", s.Name, err)
			}
			newSyns += int(tag.RowsAffected())
		}

		var firstNew string
		for i, img := range d.Images {
			u := img
			if !strings.HasPrefix(u, "http") {
				u = strings.TrimRight(m.BaseURL, "/") + "/" + strings.TrimLeft(img, "/")
			}
			var id string
			err := tx.QueryRow(ctx, `
				INSERT INTO dish_images (dish_id, image_url, source, status, sort_order, is_placeholder)
				VALUES ($1, $2, 'stock', 'approved', $3, FALSE)
				ON CONFLICT (dish_id, image_url) DO NOTHING
				RETURNING id
			`, dishID, u, i+1).Scan(&id)
			if err == nil {
				newImgs++
				if firstNew == "" {
					firstNew = id
				}
			} else if err != pgx.ErrNoRows {
				log.Fatalf("image %s: %v", u, err)
			}
		}

		// Retire placeholders for this dish once it has a real image.
		var real int
		_ = tx.QueryRow(ctx, `SELECT count(*) FROM dish_images WHERE dish_id=$1 AND NOT is_placeholder AND status='approved'`, dishID).Scan(&real)
		if real > 0 {
			var top string
			_ = tx.QueryRow(ctx, `SELECT id FROM dish_images WHERE dish_id=$1 AND NOT is_placeholder AND status='approved' ORDER BY sort_order LIMIT 1`, dishID).Scan(&top)
			tag, err := tx.Exec(ctx, `
				UPDATE menu_items SET selected_image_id = $2
				WHERE dish_id = $1 AND selected_image_id IN (SELECT id FROM dish_images WHERE dish_id = $1 AND is_placeholder)
			`, dishID, top)
			if err != nil {
				log.Fatal(err)
			}
			repointed += int(tag.RowsAffected())
			tag, err = tx.Exec(ctx, `DELETE FROM dish_images WHERE dish_id=$1 AND is_placeholder`, dishID)
			if err != nil {
				log.Fatal(err)
			}
			retired += int(tag.RowsAffected())
		}
	}

	fmt.Printf("dishes +%d, synonyms +%d, images +%d, placeholders retired %d, menu items re-pointed %d\n",
		newDishes, newSyns, newImgs, retired, repointed)
	if *dry {
		fmt.Println("dry run: rolling back, nothing written")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		log.Fatal(err)
	}
	fmt.Println("committed")
}
