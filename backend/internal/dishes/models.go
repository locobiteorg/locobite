package dishes

import (
	"time"

	"github.com/google/uuid"
)

// ResolveThreshold is the minimum pg_trgm similarity score for a dish
// name to be considered a match. Below this, callers should fall back to
// manual "search different item" / "take photo" flows.
const ResolveThreshold = 0.3

type Image struct {
	ID        uuid.UUID `json:"id"`
	DishID    uuid.UUID `json:"dish_id"`
	ImageURL  string    `json:"image_url"`
	Source    string    `json:"source"`
	Status    string    `json:"status"`
	SortOrder int       `json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
}

type ResolveResult struct {
	DishID        uuid.UUID `json:"dish_id"`
	CanonicalSlug string    `json:"canonical_slug"`
	MatchedName   string    `json:"matched_name"`
	Score         float64   `json:"score"`
	Images        []Image   `json:"images"`
}

type SearchResult struct {
	DishID        uuid.UUID `json:"dish_id"`
	CanonicalSlug string    `json:"canonical_slug"`
	DisplayName   string    `json:"display_name"`
	Score         float64   `json:"score"`
}
