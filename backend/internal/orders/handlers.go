package orders

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/locobite/backend/internal/config"
	"github.com/locobite/backend/internal/customers"
	"github.com/locobite/backend/internal/httperr"
	"github.com/locobite/backend/internal/payments"
	"github.com/locobite/backend/internal/vendors"
)

type Handler struct {
	Pool      *pgxpool.Pool
	Orders    *Postgres
	Customers customers.Repository
	Vendors   vendors.Repository
	Payments  payments.Repository
	Provider  payments.PaymentProvider
}

func (h *Handler) Routes(r chi.Router) {
	r.Post("/orders", h.Create)
	r.Post("/orders/{id}/accept", h.Accept)
	r.Post("/orders/{id}/reject", h.Reject)
	r.Post("/orders/{id}/cancel", h.Cancel)
	r.Post("/orders/{id}/preparing", h.advance(StatusPreparing))
	r.Post("/orders/{id}/ready", h.advance(StatusReady))
	r.Post("/orders/{id}/out-for-delivery", h.advance(StatusOutForDelivery))
	r.Post("/orders/{id}/delivered", h.advance(StatusDelivered))
	r.Patch("/orders/{id}/delay", h.Delay)
	r.Post("/orders/{id}/reorder", h.Reorder)
	r.Get("/customers/{id}/orders", h.ListCustomerOrders)
	r.Post("/orders/{id}/collect-payment", h.CollectPayment)
	r.Post("/orders/{id}/cash-received", h.CashReceived)
	r.Post("/webhooks/payment", h.PaymentWebhook)
	r.Post("/orders/{id}/dispute", h.FileDispute)
}

type createBody struct {
	CustomerID       uuid.UUID `json:"customer_id"`
	VendorID         uuid.UUID `json:"vendor_id"`
	TrainNumber      string    `json:"train_number"`
	Direction        string    `json:"direction"`
	SeatCoach        string    `json:"seat_coach"`
	ScheduledArrival time.Time `json:"scheduled_arrival"`
	Items            []struct {
		MenuItemID uuid.UUID `json:"menu_item_id"`
		Quantity   int       `json:"quantity"`
	} `json:"items"`
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var body createBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if body.CustomerID == uuid.Nil || body.VendorID == uuid.Nil || len(body.Items) == 0 {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "customer_id, vendor_id, and items are required")
		return
	}

	cust, err := h.Customers.GetByID(ctx, body.CustomerID)
	if errors.Is(err, customers.ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "customer_not_found", "customer not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load customer")
		return
	}
	if cust.DeletedAt != nil {
		httperr.Write(w, http.StatusForbidden, "customer_deleted", "customer account is deleted")
		return
	}
	if cust.IsBlockedForDues {
		httperr.Write(w, http.StatusForbidden, "dues_blocked",
			"customer is blocked for outstanding dues; use POST /customers/{id}/clear-dues")
		return
	}

	ids := make([]uuid.UUID, 0, len(body.Items))
	qty := map[uuid.UUID]int{}
	for _, it := range body.Items {
		if it.Quantity <= 0 {
			httperr.Write(w, http.StatusBadRequest, "validation_error", "item quantity must be > 0")
			return
		}
		ids = append(ids, it.MenuItemID)
		qty[it.MenuItemID] += it.Quantity
	}
	menu, err := h.Orders.GetMenuItems(ctx, ids)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load menu items")
		return
	}
	byID := map[uuid.UUID]MenuItem{}
	for _, m := range menu {
		byID[m.ID] = m
	}
	var lines []LineItem
	amount := 0
	hasTen := false
	for _, it := range body.Items {
		m, ok := byID[it.MenuItemID]
		if !ok {
			httperr.Write(w, http.StatusBadRequest, "menu_item_not_found", "menu item does not exist")
			return
		}
		if m.VendorID != body.VendorID {
			httperr.Write(w, http.StatusBadRequest, "menu_item_vendor_mismatch", "menu item does not belong to vendor")
			return
		}
		if m.IsTenMin {
			hasTen = true
		}
		lineTotal := m.PricePaise * it.Quantity
		amount += lineTotal
		lines = append(lines, LineItem{
			MenuItemID:     m.ID,
			Name:           m.Name,
			Quantity:       it.Quantity,
			UnitPricePaise: m.PricePaise,
			IsTenMin:       m.IsTenMin,
		})
	}

	mode, err := h.Orders.VendorAcceptMode(ctx, body.VendorID)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "vendor_not_found", "vendor not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load vendor")
		return
	}

	status := StatusRequested
	if ImmediateAcceptOnCreate(mode) {
		status = StatusAccepted
	}

	o := &Order{
		CustomerID:       body.CustomerID,
		VendorID:         body.VendorID,
		Status:           status,
		AmountPaise:      amount,
		TrainNumber:      body.TrainNumber,
		Direction:        body.Direction,
		SeatCoach:        body.SeatCoach,
		ScheduledArrival: body.ScheduledArrival,
		HasTenMinItem:    hasTen,
		Items:            lines,
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)

	if err := h.Orders.Create(ctx, tx, o); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to create order")
		return
	}
	due, err := h.Customers.ApplyOldestPendingDue(ctx, tx, body.CustomerID, o.ID)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to apply dues")
		return
	}
	if due != nil {
		if err := h.Orders.AddToAmount(ctx, tx, o.ID, due.AmountPaise); err != nil {
			httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to add due to order")
			return
		}
		o.AmountPaise += due.AmountPaise
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit order")
		return
	}
	httperr.JSON(w, http.StatusCreated, orderJSON(o))
}

func (h *Handler) Accept(w http.ResponseWriter, r *http.Request) {
	h.transition(w, r, StatusAccepted, nil)
}

type rejectBody struct {
	Reason RejectionReason `json:"reason"`
}

func (h *Handler) Reject(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var body rejectBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if !ValidRejectionReason(body.Reason) {
		httperr.Write(w, http.StatusBadRequest, "invalid_reason", "reason must be out_of_stock, too_busy, closing_soon, or other")
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
	if !CanReject(o.Status, body.Reason) {
		httperr.Write(w, http.StatusConflict, "invalid_transition", "cannot reject order in current state")
		return
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)

	reason := body.Reason
	if err := h.Orders.UpdateStatus(ctx, tx, o.ID, StatusRejected, &reason); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to reject order")
		return
	}

	since := time.Now().UTC().Add(-config.RollingWindow)
	n, err := h.Customers.CountVendorRejections(ctx, o.VendorID, since)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to count rejections")
		return
	}
	// Count does not include this in-flight row until commit; treat current as n+1.
	if n+1 > config.FreeRejectionsPerWindow {
		total := config.RejectionPenaltyPaise(o.AmountPaise)
		custShare, platShare := config.SplitPenalty(total)
		if err := h.Customers.InsertPenalty(ctx, tx, o.VendorID, o.ID, string(reason), total, custShare, platShare); err != nil {
			httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to record penalty")
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	o.Status = StatusRejected
	o.RejectionReason = &reason
	httperr.JSON(w, http.StatusOK, orderJSON(o))
}

func (h *Handler) Cancel(w http.ResponseWriter, r *http.Request) {
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
	if !CanCancel(o.View(), time.Now().UTC()) {
		httperr.Write(w, http.StatusConflict, "cancel_not_allowed", "order cannot be cancelled")
		return
	}

	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Orders.UpdateStatus(ctx, tx, o.ID, StatusCancelled, nil); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to cancel")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	o.Status = StatusCancelled
	httperr.JSON(w, http.StatusOK, orderJSON(o))
}

func (h *Handler) advance(to Status) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		h.transition(w, r, to, nil)
	}
}

func (h *Handler) transition(w http.ResponseWriter, r *http.Request, to Status, reason *RejectionReason) {
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
	if !CanTransition(o.Status, to) {
		httperr.Write(w, http.StatusConflict, "invalid_transition", "invalid status transition")
		return
	}
	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Orders.UpdateStatus(ctx, tx, o.ID, to, reason); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to update status")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	o.Status = to
	httperr.JSON(w, http.StatusOK, orderJSON(o))
}

type delayBody struct {
	Chip string `json:"chip"`
}

func (h *Handler) Delay(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var body delayBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	switch body.Chip {
	case "+15", "+30", "on-time":
	default:
		httperr.Write(w, http.StatusBadRequest, "invalid_chip", "chip must be +15, +30, or on-time")
		return
	}
	id, err := parseID(r)
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid order id")
		return
	}
	now := time.Now().UTC()
	tx, err := h.Pool.Begin(ctx)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to start transaction")
		return
	}
	defer tx.Rollback(ctx)
	if err := h.Orders.UpdateDelay(ctx, tx, id, now); err != nil {
		if errors.Is(err, ErrNotFound) {
			httperr.Write(w, http.StatusNotFound, "order_not_found", "order not found")
			return
		}
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to update delay")
		return
	}
	if err := tx.Commit(ctx); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to commit")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"id":               id,
		"chip":             body.Chip,
		"delay_updated_at": now,
	})
}

func (h *Handler) ListCustomerOrders(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	cid, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid customer id")
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	list, err := h.Orders.ListByCustomer(ctx, cid, limit, offset)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to list orders")
		return
	}
	out := make([]map[string]any, 0, len(list))
	for i := range list {
		o := list[i]
		m := orderJSON(&o)
		m["reorderable"] = o.Status == StatusDelivered || o.Status == StatusCancelled
		out = append(out, m)
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"orders": out,
		"limit":  limit,
		"offset": offset,
	})
}

func (h *Handler) Reorder(w http.ResponseWriter, r *http.Request) {
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
	cart := make([]map[string]any, 0, len(o.Items))
	for _, it := range o.Items {
		cart = append(cart, map[string]any{
			"menu_item_id":     it.MenuItemID,
			"name":             it.Name,
			"quantity":         it.Quantity,
			"unit_price_paise": it.UnitPricePaise,
		})
	}
	httperr.JSON(w, http.StatusOK, map[string]any{
		"source_order_id": o.ID,
		"vendor_id":       o.VendorID,
		"cart":            cart,
	})
}

func parseID(r *http.Request) (uuid.UUID, error) {
	return uuid.Parse(chi.URLParam(r, "id"))
}

func orderJSON(o *Order) map[string]any {
	return map[string]any{
		"id":                o.ID,
		"customer_id":       o.CustomerID,
		"vendor_id":         o.VendorID,
		"status":            o.Status,
		"amount_paise":      o.AmountPaise,
		"train_number":      o.TrainNumber,
		"direction":         o.Direction,
		"seat_coach":        o.SeatCoach,
		"scheduled_arrival": o.ScheduledArrival,
		"delay_updated_at":  o.DelayUpdatedAt,
		"rejection_reason":  o.RejectionReason,
		"pickup_status":     o.PickupStatus,
		"has_ten_min_item":  o.HasTenMinItem,
		"payment_verified":  o.PaymentVerified,
		"created_at":        o.CreatedAt,
		"updated_at":        o.UpdatedAt,
		"items":             o.Items,
	}
}
