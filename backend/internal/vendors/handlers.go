package vendors

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
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
	r.Get("/vendors", h.ListPublic)
	r.Post("/vendors/login", h.Login)
	r.Get("/vendors/{id}", h.Get)
	r.Patch("/vendors/{id}", h.UpdateProfile)
	r.Post("/vendors/{id}/offline-sale", h.OfflineSale)
	r.Post("/vendors/{id}/tap", h.RecordTap)

	r.Get("/vendors/{id}/menu-items", h.ListMenuItems)
	r.Post("/vendors/{id}/menu-items", h.CreateMenuItem)
	r.Patch("/vendors/{id}/menu-items/{itemId}", h.UpdateMenuItem)
	r.Patch("/vendors/{id}/menu-items/{itemId}/availability", h.SetMenuItemAvailability)
	r.Delete("/vendors/{id}/menu-items/{itemId}", h.DeleteMenuItem)
}

// loginBody mirrors customers.Login: same Supabase email-OTP flow, role
// (vendor vs customer) is resolved by which table the profile lives in.
type loginBody struct {
	Email     string `json:"email"`
	OwnerName string `json:"owner_name"`
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var body loginBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	email := strings.ToLower(strings.TrimSpace(body.Email))
	if email == "" || !strings.Contains(email, "@") {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "a valid email is required")
		return
	}

	v, err := h.Repo.GetByEmail(ctx, email)
	if err == nil {
		httperr.JSON(w, http.StatusOK, vendorJSON(v))
		return
	}
	if !errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load vendor")
		return
	}

	owner := strings.TrimSpace(body.OwnerName)
	nv := &Vendor{Email: &email}
	if owner != "" {
		nv.OwnerName = &owner
	}
	if err := h.Repo.Create(ctx, nv); err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to create vendor")
		return
	}
	httperr.JSON(w, http.StatusCreated, vendorJSON(nv))
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	v, err := h.Repo.GetByID(ctx, id)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "vendor_not_found", "vendor not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to load vendor")
		return
	}
	httperr.JSON(w, http.StatusOK, vendorJSON(v))
}

// UpdateProfile accepts a sparse partial body (any of: name, station_code,
// owner_name, fssai_status, accept_mode, stall_image_url, subscription_tier).
// Used by business-details, accept-mode, and stall-image onboarding steps.
func (h *Handler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	var fields map[string]any
	if err := json.NewDecoder(r.Body).Decode(&fields); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	v, err := h.Repo.UpdateProfile(ctx, id, fields)
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "vendor_not_found", "vendor not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to update vendor")
		return
	}
	httperr.JSON(w, http.StatusOK, vendorJSON(v))
}

func vendorJSON(v *Vendor) map[string]any {
	return map[string]any{
		"id":                v.ID,
		"name":              v.Name,
		"station_code":      v.StationCode,
		"subscription_tier": v.SubscriptionTier,
		"accept_mode":       v.AcceptMode,
		"is_active":         v.IsActive,
		"fssai_status":      v.FssaiStatus,
		"email":             v.Email,
		"owner_name":        v.OwnerName,
		"stall_image_url":   v.StallImageURL,
	}
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

type menuItemBody struct {
	Name            string     `json:"name"`
	PricePaise      int        `json:"price_paise"`
	DietType        string     `json:"diet_type"`
	IsOTC           bool       `json:"is_otc"`
	IsTenMin        bool       `json:"is_ten_min"`
	DishID          *uuid.UUID `json:"dish_id"`
	SelectedImageID *uuid.UUID `json:"selected_image_id"`
	ImageSourceNote *string    `json:"image_source_note"`
}

func (b menuItemBody) toInput() MenuItemInput {
	return MenuItemInput{
		Name: b.Name, PricePaise: b.PricePaise, DietType: b.DietType,
		IsOTC: b.IsOTC, IsTenMin: b.IsTenMin, DishID: b.DishID,
		SelectedImageID: b.SelectedImageID, ImageSourceNote: b.ImageSourceNote,
	}
}

func menuItemJSON(m *MenuItem) map[string]any {
	return map[string]any{
		"id":                m.ID,
		"vendor_id":         m.VendorID,
		"name":              m.Name,
		"price_paise":       m.PricePaise,
		"diet_type":         m.DietType,
		"is_otc":            m.IsOTC,
		"is_ten_min":        m.IsTenMin,
		"is_available":      m.IsAvailable,
		"dish_id":           m.DishID,
		"selected_image_id": m.SelectedImageID,
		"image_source_note": m.ImageSourceNote,
		"photo_url":         m.PhotoURL,
		"created_at":        m.CreatedAt,
	}
}

func (h *Handler) ListMenuItems(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vendorID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	items, err := h.Repo.ListMenuItems(ctx, vendorID)
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to list menu items")
		return
	}
	out := make([]map[string]any, 0, len(items))
	for i := range items {
		out = append(out, menuItemJSON(&items[i]))
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"menu_items": out})
}

func (h *Handler) CreateMenuItem(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vendorID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	var body menuItemBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if strings.TrimSpace(body.Name) == "" || body.PricePaise <= 0 {
		httperr.Write(w, http.StatusBadRequest, "validation_error", "name and a positive price_paise are required")
		return
	}
	m, err := h.Repo.CreateMenuItem(ctx, vendorID, body.toInput())
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to create menu item")
		return
	}
	httperr.JSON(w, http.StatusCreated, menuItemJSON(m))
}

func (h *Handler) UpdateMenuItem(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vendorID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	itemID, err := uuid.Parse(chi.URLParam(r, "itemId"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid menu item id")
		return
	}
	var body menuItemBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	m, err := h.Repo.UpdateMenuItem(ctx, vendorID, itemID, body.toInput())
	if errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "menu_item_not_found", "menu item not found")
		return
	}
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to update menu item")
		return
	}
	httperr.JSON(w, http.StatusOK, menuItemJSON(m))
}

type availabilityBody struct {
	IsAvailable bool `json:"is_available"`
}

func (h *Handler) SetMenuItemAvailability(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vendorID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	itemID, err := uuid.Parse(chi.URLParam(r, "itemId"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid menu item id")
		return
	}
	var body availabilityBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_json", "invalid request body")
		return
	}
	if err := h.Repo.SetMenuItemAvailability(ctx, vendorID, itemID, body.IsAvailable); errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "menu_item_not_found", "menu item not found")
		return
	} else if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to update availability")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"id": itemID, "is_available": body.IsAvailable})
}

func (h *Handler) DeleteMenuItem(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vendorID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid vendor id")
		return
	}
	itemID, err := uuid.Parse(chi.URLParam(r, "itemId"))
	if err != nil {
		httperr.Write(w, http.StatusBadRequest, "invalid_id", "invalid menu item id")
		return
	}
	if err := h.Repo.DeleteMenuItem(ctx, vendorID, itemID); errors.Is(err, ErrNotFound) {
		httperr.Write(w, http.StatusNotFound, "menu_item_not_found", "menu item not found")
		return
	} else if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to delete menu item")
		return
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"status": "deleted"})
}

// ListPublic powers the customer app's discovery: GET /vendors?station_code=UD
// returns live vendors with their available menus (see Postgres.ListPublic).
func (h *Handler) ListPublic(w http.ResponseWriter, r *http.Request) {
	list, err := h.Repo.ListPublic(r.Context(), strings.TrimSpace(r.URL.Query().Get("station_code")))
	if err != nil {
		httperr.Write(w, http.StatusInternalServerError, "internal_error", "failed to list vendors")
		return
	}
	out := make([]map[string]any, 0, len(list))
	for i := range list {
		v := list[i]
		menu := make([]map[string]any, 0, len(v.Menu))
		for j := range v.Menu {
			menu = append(menu, menuItemJSON(&v.Menu[j]))
		}
		m := vendorJSON(&v.Vendor)
		delete(m, "email")
		delete(m, "owner_name")
		m["trusted"] = v.Trusted
		m["menu_items"] = menu
		out = append(out, m)
	}
	httperr.JSON(w, http.StatusOK, map[string]any{"vendors": out})
}
