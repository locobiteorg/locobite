package vendors

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/locobite/backend/internal/httperr"
	"github.com/locobite/backend/internal/payments"
)

type Handler struct {
	Pool     *pgxpool.Pool
	Repo     Repository
	Payments payments.Repository
	Provider payments.PaymentProvider
}

func (h *Handler) Routes(r chi.Router) {
	r.Post("/vendors/{id}/offline-sale", h.OfflineSale)
	r.Post("/vendors/{id}/tap", h.RecordTap)
}

type tapBody struct {
	CustomerID uuid.UUID `json:"customer_id"`
}

func (h *Handler) RecordTap(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vendorID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_vendor_id", "invalid vendor id")
		return
	}
	var body tapBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if body.CustomerID == uuid.Nil {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "customer_id is required")
		return
	}
	if err := h.Repo.RecordTap(ctx, vendorID, body.CustomerID); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record tap")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"status": "recorded"})
}

type offlineSaleBody struct {
	AmountPaise int `json:"amount_paise"`
}

func (h *Handler) OfflineSale(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	var body offlineSaleBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if body.AmountPaise <= 0 {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "amount_paise must be > 0")
		return
	}
	if _, err := h.Repo.GetByID(ctx, id); errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "vendor_not_found", "vendor not found")
		return
	} else if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load vendor")
		return
	}

	qr, err := h.Provider.GenerateUPIQR(ctx, body.AmountPaise, "offline:"+id.String())
	if err != nil {
		httperr.Write(w, http.StatusBadGateway, "payment_provider_error", "failed to generate UPI QR")
		return
	}
	now := time.Now().UTC()
	sale := &OfflineSale{
		VendorID:      id,
		AmountPaise:   body.AmountPaise,
		QRGeneratedAt: &now,
		ProviderRef:   &qr.ProviderRef,
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Repo.InsertOfflineSale(ctx, tx, sale); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record offline sale")
		return
	}
	ev := &payments.Event{
		OfflineSaleID: &sale.ID,
		QRGeneratedAt: &now,
		AmountPaise:   body.AmountPaise,
		ProviderRef:   &qr.ProviderRef,
	}
	if err := h.Payments.InsertQR(ctx, tx, ev); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record payment event")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusCreated, map[string]any{
		"offline_sale_id":  sale.ID,
		"vendor_id":        id,
		"amount_paise":     body.AmountPaise,
		"qr_payload":       qr.QRPayload,
		"provider_ref":     qr.ProviderRef,
		"qr_generated_at":  now,
		"payment_verified": false,
	})
}
