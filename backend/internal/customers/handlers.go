package customers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/locobite/backend/internal/httperr"
	"github.com/locobite/backend/internal/payments"
)

type Handler struct {
	Pool     *pgxpool.Pool
	Repo     Repository
	Provider payments.PaymentProvider
}

func (h *Handler) Routes(r chi.Router) {
	r.Post("/customers/login", h.Login)
	r.Get("/customers/{id}", h.Get)
	r.Post("/customers/{id}/clear-dues", h.ClearDues)
	r.Delete("/customers/{id}", h.Delete)
}

type loginBody struct {
	Phone string `json:"phone"`
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var body loginBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if len(body.Phone) < 10 {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "phone number must be at least 10 digits")
		return
	}

	c, err := h.Repo.GetByPhone(ctx, body.Phone)
	if err == nil {
		// Found customer. If soft-deleted, reactivate.
		if c.DeletedAt != nil {
			// Update to undelete
			tx, txErr := h.Pool.Begin(ctx)
			if txErr != nil {
				httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
				return
			}
			defer tx.Rollback(ctx)
			_, execErr := tx.Exec(ctx, `
				UPDATE customers
				SET deleted_at = NULL, name = $2
				WHERE id = $1
			`, c.ID, "Traveller "+body.Phone[len(body.Phone)-4:])
			if execErr != nil {
				httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to reactivate customer")
				return
			}
			if commitErr := tx.Commit(ctx); commitErr != nil {
				httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
				return
			}
			c.DeletedAt = nil
			c.Name = "Traveller " + body.Phone[len(body.Phone)-4:]
		}

		httperr.JSON(w, http.StatusOK, map[string]any{
			"id":                 c.ID,
			"phone":              c.Phone,
			"name":               c.Name,
			"dues_balance_paise": c.DuesBalancePaise,
			"is_blocked_for_dues": c.IsBlockedForDues,
		})
		return
	}

	if !errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to query customer")
		return
	}

	// Create new customer
	name := "Traveller "
	if len(body.Phone) >= 4 {
		name += body.Phone[len(body.Phone)-4:]
	} else {
		name += body.Phone
	}

	newC := &Customer{
		ID:    uuid.New(),
		Phone: body.Phone,
		Name:  name,
	}

	if err := h.Repo.Create(ctx, newC); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to create customer")
		return
	}

	httperr.JSON(w, http.StatusCreated, map[string]any{
		"id":                 newC.ID,
		"phone":              newC.Phone,
		"name":               newC.Name,
		"dues_balance_paise": 0,
		"is_blocked_for_dues": false,
	})
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid customer id")
		return
	}
	c, err := h.Repo.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "customer_not_found", "customer not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load customer")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"id":                 c.ID,
		"phone":              c.Phone,
		"name":               c.Name,
		"dues_balance_paise": c.DuesBalancePaise,
		"is_blocked_for_dues": c.IsBlockedForDues,
		"deleted_at":         c.DeletedAt,
	})
}

func (h *Handler) ClearDues(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid customer id")
		return
	}
	c, err := h.Repo.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "customer_not_found", "customer not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load customer")
		return
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)

	total, err := h.Repo.ClearPendingDues(ctx, tx, id)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to clear dues")
		return
	}
	if err := h.Provider.CollectDues(ctx, id.String(), total); err != nil {
		httperr.Write(w, http.StatusBadGateway, "payment_provider_error", "failed to collect dues payment")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"customer_id":        c.ID,
		"cleared_paise":      total,
		"dues_balance_paise": 0,
		"is_blocked_for_dues": false,
	})
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid customer id")
		return
	}
	c, err := h.Repo.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "customer_not_found", "customer not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load customer")
		return
	}
	if c.DeletedAt != nil {
		httperr.Write(w, http.StatusConflict, "already_deleted", "customer already deleted")
		return
	}
	if c.DuesBalancePaise > 0 || c.IsBlockedForDues {
		httperr.Write(w, http.StatusConflict, "dues_outstanding",
			"cannot delete account while dues_balance_paise > 0 or blocked for dues; use POST /customers/{id}/clear-dues")
		return
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Repo.SoftDelete(ctx, tx, id); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to delete customer")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	// Soft delete only: orders, payment_events, and dispute rows are retained.
	// Retention period for these audit records must match RBI-mandated audit-trail
	// retention; do not hardcode a duration here — needs compliance input.
	httperr.JSON(w, http.StatusOK, map[string]any{
		"customer_id": id,
		"deleted":     true,
	})
}
