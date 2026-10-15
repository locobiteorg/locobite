package dishes

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Repository interface {
	// Resolve fuzzy-matches free text (an item name typed manually, or one
	// line of Gemini OCR output) against dish_synonyms and returns the best
	// hit above ResolveThreshold, with its top approved images attached.
	Resolve(ctx context.Context, text, lang string) (*ResolveResult, error)
	// Search returns up to 20 candidate dishes for the manual
	// "search different item" fallback.
	Search(ctx context.Context, q, lang string) ([]SearchResult, error)
	// ImagesForDish returns the full approved image set for the swap carousel.
	ImagesForDish(ctx context.Context, dishID uuid.UUID) ([]Image, error)
	// SubmitVendorImage records an image a vendor already uploaded to
	// Storage; it is usable by that vendor immediately but pending_review
	// for everyone else until approved.
	SubmitVendorImage(ctx context.Context, dishID, vendorID uuid.UUID, imageURL string) (*Image, error)
}

type Postgres struct {
	Pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{Pool: pool}
}

// normalizeTrim mirrors the normalized_name convention used at seed time
// (lowercase, trimmed); Postgres does the heavy lifting (trgm similarity).
func normalizeTrim(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}

func (p *Postgres) Resolve(ctx context.Context, text, lang string) (*ResolveResult, error) {
	q := normalizeTrim(text)
	if q == "" {
		return nil, ErrNotFound
	}
	row := p.Pool.QueryRow(ctx, `
		SELECT dc.id, dc.canonical_slug, ds.display_name, similarity(ds.normalized_name, $1) AS score
		FROM dish_synonyms ds
		JOIN dish_catalog dc ON dc.id = ds.dish_id
		WHERE similarity(ds.normalized_name, $1) > $2
		ORDER BY (ds.language_code = $3) DESC, score DESC
		LIMIT 1
	`, q, ResolveThreshold, lang)

	var res ResolveResult
	if err := row.Scan(&res.DishID, &res.CanonicalSlug, &res.MatchedName, &res.Score); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	images, err := p.ImagesForDish(ctx, res.DishID)
	if err != nil {
		return nil, err
	}
	res.Images = images
	return &res, nil
}

func (p *Postgres) Search(ctx context.Context, q, lang string) ([]SearchResult, error) {
	query := normalizeTrim(q)
	if query == "" {
		return nil, nil
	}
	_ = lang // language currently only affects ranking, not filtering, so more results surface
	rows, err := p.Pool.Query(ctx, `
		SELECT dc.id, dc.canonical_slug, ds.display_name, MAX(similarity(ds.normalized_name, $1)) AS score
		FROM dish_synonyms ds
		JOIN dish_catalog dc ON dc.id = ds.dish_id
		WHERE ds.normalized_name ILIKE '%' || $1 || '%' OR similarity(ds.normalized_name, $1) > 0.15
		GROUP BY dc.id, dc.canonical_slug, ds.display_name
		ORDER BY score DESC
		LIMIT 20
	`, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []SearchResult
	seen := map[uuid.UUID]bool{}
	for rows.Next() {
		var r SearchResult
		if err := rows.Scan(&r.DishID, &r.CanonicalSlug, &r.DisplayName, &r.Score); err != nil {
			return nil, err
		}
		if seen[r.DishID] {
			continue
		}
		seen[r.DishID] = true
		out = append(out, r)
	}
	return out, rows.Err()
}

func (p *Postgres) ImagesForDish(ctx context.Context, dishID uuid.UUID) ([]Image, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT id, dish_id, image_url, source::text, status::text, sort_order, created_at
		FROM dish_images
		WHERE dish_id = $1 AND status = 'approved'
		ORDER BY sort_order ASC
	`, dishID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Image
	for rows.Next() {
		var img Image
		if err := rows.Scan(&img.ID, &img.DishID, &img.ImageURL, &img.Source, &img.Status, &img.SortOrder, &img.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, img)
	}
	return out, rows.Err()
}

func (p *Postgres) SubmitVendorImage(ctx context.Context, dishID, vendorID uuid.UUID, imageURL string) (*Image, error) {
	var img Image
	err := p.Pool.QueryRow(ctx, `
		INSERT INTO dish_images (dish_id, image_url, source, status, sort_order, submitted_by_vendor_id)
		VALUES ($1, $2, 'vendor_submitted', 'pending_review',
		        COALESCE((SELECT MAX(sort_order) + 1 FROM dish_images WHERE dish_id = $1), 0),
		        $3)
		RETURNING id, dish_id, image_url, source::text, status::text, sort_order, created_at
	`, dishID, imageURL, vendorID).Scan(&img.ID, &img.DishID, &img.ImageURL, &img.Source, &img.Status, &img.SortOrder, &img.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &img, nil
}
