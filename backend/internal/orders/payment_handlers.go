package orders

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/locobite/backend/internal/config"
	"github.com/locobite/backend/internal/httperr"
	"github.com/locobite/backend/internal/payments"
)

func (h *Handler) CollectPayment(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := parseID(r)
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid order id")
		return
	}
	o, err := h.Orders.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "order_not_found", "order not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load order")
		return
	}

	qr, err := h.Provider.GenerateUPIQR(ctx, o.AmountPaise, o.ID.String())
	if err != nil {
		httperr.Write(w, http.StatusBadGateway, "payment_provider_error", "failed to generate UPI QR")
		return
	}
	now := time.Now().UTC()
	oid := o.ID
	ev := &payments.Event{
		OrderID:       &oid,
		QRGeneratedAt: &now,
		AmountPaise:   o.AmountPaise,
		ProviderRef:   &qr.ProviderRef,
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Payments.InsertQR(ctx, tx, ev); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record payment event")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"order_id":         o.ID,
		"amount_paise":     o.AmountPaise,
		"qr_payload":       qr.QRPayload,
		"provider_ref":     qr.ProviderRef,
		"qr_generated_at":  now,
		"payment_event_id": ev.ID,
	})
}

func (h *Handler) CashReceived(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := parseID(r)
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid order id")
		return
	}
	o, err := h.Orders.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "order_not_found", "order not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load order")
		return
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Payments.InsertCash(ctx, tx, o.ID, o.AmountPaise); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record cash")
		return
	}
	// Cash is self-reported: explicitly NOT payment-verified for Trusted Vendor.
	if err := h.Orders.SetPaymentVerified(ctx, tx, o.ID, false); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to mark unverified")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"order_id":          o.ID,
		"type":              "cash_confirmed",
		"amount_paise":      o.AmountPaise,
		"payment_verified":  false,
	})
}

type webhookBody struct {
	EventID     string `json:"event_id"`
	ProviderRef string `json:"provider_ref"`
	Status      string `json:"status"`
}

func (h *Handler) PaymentWebhook(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	payload, err := io.ReadAll(r.Body)
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_body", "unable to read body")
		return
	}
	sig := r.Header.Get("X-Webhook-Signature")
	if err := payments.VerifyWebhookSignature(payload, sig, mustWebhookSecret()); err != nil {
		httperr.Write(w, http.StatusUnauthorized, "invalid_signature", err.Error())
		return
	}

	var body webhookBody
	if err := json.Unmarshal(payload, &body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid webhook payload")
		return
	}
	if body.EventID == "" || body.ProviderRef == "" {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "event_id and provider_ref are required")
		return
	}

	exists, err := h.Payments.ProviderEventExists(ctx, body.EventID)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed idempotency check")
		return
	}
	if exists {
		httperr.JSON(w, http.StatusOK, map[string]any{"status": "duplicate", "event_id": body.EventID})
		return
	}

	ev, err := h.Payments.GetByProviderRef(ctx, body.ProviderRef)
	if errors.Is(err, payments.ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "payment_not_found", "no payment event for provider_ref")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load payment event")
		return
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)

	if err := h.Payments.ConfirmUPI(ctx, tx, ev.ID, body.EventID, payload); err != nil {
		if errors.Is(err, payments.ErrDuplicateEvent) {
			httperr.JSON(w, http.StatusOK, map[string]any{"status": "duplicate", "event_id": body.EventID})
			return
		}
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to confirm payment")
		return
	}

	if ev.OrderID != nil {
		if err := h.Orders.SetPaymentVerified(ctx, tx, *ev.OrderID, true); err != nil {
			httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to mark trusted-vendor verified")
			return
		}
	}
	if ev.OfflineSaleID != nil {
		if err := h.Vendors.ConfirmOfflineSale(ctx, tx, *ev.OfflineSaleID); err != nil {
			httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to confirm offline sale")
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"status": "confirmed", "event_id": body.EventID})
}

type disputeBody struct {
	Type string `json:"type"`
}

func (h *Handler) FileDispute(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var body disputeBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if body.Type != "not_collected" && body.Type != "customer_not_at_seat" {
		httperr.Write(w, http.StatusBadRequest, "invalid_type", "type must be not_collected or customer_not_at_seat")
		return
	}
	id, err := parseID(r)
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid order id")
		return
	}
	o, err := h.Orders.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "order_not_found", "order not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load order")
		return
	}
	if !CanTransition(o.Status, StatusDisputed) {
		httperr.Write(w, http.StatusConflict, "invalid_transition", "order cannot be disputed in current state")
		return
	}

	qr, err := h.Payments.LatestQRForOrder(ctx, o.ID)
	if errors.Is(err, payments.ErrNotFound) || qr == nil || qr.QRGeneratedAt == nil {
		httperr.Write(w, http.StatusConflict, "dispute_too_early", "no QR generated; dispute timer has not started")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load payment event")
		return
	}
	now := time.Now().UTC()
	if now.Sub(*qr.QRGeneratedAt) > config.DisputeWindow {
		httperr.Write(w, http.StatusConflict, "dispute_window_expired", "dispute window after QR generation has expired")
		return
	}

	cust, err := h.Customers.GetByID(ctx, o.CustomerID)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load customer")
		return
	}

	since := now.Add(-config.RollingWindow)
	prior, err := h.Customers.CountDisputesByPhone(ctx, cust.Phone, since)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to count disputes")
		return
	}
	vendorCount, err := h.Customers.CountVendorDisputes(ctx, o.VendorID, since)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to count vendor disputes")
		return
	}

	refund := config.RefundTierPaise(o.AmountPaise)

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)

	if err := h.Orders.UpdateStatus(ctx, tx, o.ID, StatusDisputed, nil); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to update order")
		return
	}
	did, err := h.Customers.InsertDispute(ctx, tx, o.ID, o.CustomerID, o.VendorID, body.Type, refund)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to create dispute")
		return
	}

	waiver := prior < config.FreeDisputesPerWindow
	if !waiver {
		if err := h.Customers.AddPendingDue(ctx, tx, o.CustomerID, refund, "dispute_over_waiver"); err != nil {
			httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record customer due")
			return
		}
	}
	chargedVendor := vendorCount < config.VendorDisputeCapPerWindow
	if chargedVendor {
		if err := h.Customers.InsertVendorDisputeLog(ctx, tx, o.VendorID, did); err != nil {
			httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to log vendor dispute")
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusCreated, map[string]any{
		"dispute_id":              did,
		"order_id":                o.ID,
		"type":                    body.Type,
		"refund_tier_paise":       refund,
		"customer_waiver":         waiver,
		"vendor_claim_charged":    chargedVendor,
	})
}

// webhookSecret is set from main via SetWebhookSecret.
var webhookSecret string

func SetWebhookSecret(s string) {
	webhookSecret = s
}

func mustWebhookSecret() string {
	return webhookSecret
}
