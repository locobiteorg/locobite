package dishes

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/locobite/backend/internal/httperr"
)

type Handler struct {
	Repo Repository
}

// Routes are mounted under /api/v1/dishes, called from both manual name
// entry and Gemini extraction output to auto-suggest an image per item.
func (h *Handler) Routes(r chi.Router) {
	r.Get("/api/v1/dishes/resolve", h.Resolve)
	r.Get("/api/v1/dishes/search", h.Search)
	r.Get("/api/v1/dishes/{dish_id}/images", h.Images)
	r.Post("/api/v1/dishes/images/submit", h.SubmitImage)
}

func (h *Handler) Resolve(w http.ResponseWriter, r *http.Request) {
	text := r.URL.Query().Get("text")
	lang := r.URL.Query().Get("lang")
	if strings.TrimSpace(text) == "" {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "text is required")
		return
	}
	res, err := h.Repo.Resolve(r.Context(), text, lang)
	if errors.Is(err, ErrNotFound) {
		httperr.JSON(w, http.StatusOK, map[string]any{"matched": false})
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to resolve dish")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"matched": true, "result": res})
}

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	lang := r.URL.Query().Get("lang")
	if strings.TrimSpace(q) == "" {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "q is required")
		return
	}
	results, err := h.Repo.Search(r.Context(), q, lang)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to search dishes")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"results": results})
}

func (h *Handler) Images(w http.ResponseWriter, r *http.Request) {
	dishID, err := uuid.Parse(chi.URLParam(r, "dish_id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid dish id")
		return
	}
	images, err := h.Repo.ImagesForDish(r.Context(), dishID)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load images")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"images": images})
}

type submitImageBody struct {
	DishID   uuid.UUID `json:"dish_id"`
	VendorID uuid.UUID `json:"vendor_id"`
	ImageURL string    `json:"image_url"`
}

func (h *Handler) SubmitImage(w http.ResponseWriter, r *http.Request) {
	var body submitImageBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if body.DishID == uuid.Nil || body.VendorID == uuid.Nil || strings.TrimSpace(body.ImageURL) == "" {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "dish_id, vendor_id, and image_url are required")
		return
	}
	img, err := h.Repo.SubmitVendorImage(r.Context(), body.DishID, body.VendorID, body.ImageURL)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to submit image")
		return
	}
	httperr.JSON(w, http.StatusCreated, img)
}
