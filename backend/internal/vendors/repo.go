package vendors

import (
	"context"
	"errors"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Vendor struct {
	ID               uuid.UUID
	Name             string
	StationCode      string
	SubscriptionTier string
	AcceptMode       string
	IsActive         bool
	FssaiStatus      string
	Email            *string
	OwnerName        *string
	StallImageURL    *string
}

type OfflineSale struct {
	ID              uuid.UUID
	VendorID        uuid.UUID
	AmountPaise     int
	QRGeneratedAt   *time.Time
	ConfirmedAt     *time.Time
	PaymentVerified bool
	ProviderRef     *string
}

// MenuItem is the vendor-management view of a menu item (superset of
// orders.MenuItem, which only needs the fields required to price an order).
type MenuItem struct {
	ID              uuid.UUID
	VendorID        uuid.UUID
	Name            string
	PricePaise      int
	DietType        string
	IsOTC           bool
	IsTenMin        bool
	IsAvailable     bool
	DishID          *uuid.UUID
	SelectedImageID *uuid.UUID
	ImageSourceNote *string
	PhotoURL        *string
	CreatedAt       time.Time
}

type MenuItemInput struct {
	Name            string
	PricePaise      int
	DietType        string
	IsOTC           bool
	IsTenMin        bool
	DishID          *uuid.UUID
	SelectedImageID *uuid.UUID
	ImageSourceNote *string
}

type Repository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*Vendor, error)
	GetByEmail(ctx context.Context, email string) (*Vendor, error)
	Create(ctx context.Context, v *Vendor) error
	UpdateProfile(ctx context.Context, id uuid.UUID, fields map[string]any) (*Vendor, error)
	InsertOfflineSale(ctx context.Context, tx pgx.Tx, s *OfflineSale) error
	ConfirmOfflineSale(ctx context.Context, tx pgx.Tx, id uuid.UUID) error
	RecordTap(ctx context.Context, vendorID, customerID uuid.UUID) error

	ListMenuItems(ctx context.Context, vendorID uuid.UUID) ([]MenuItem, error)
	CreateMenuItem(ctx context.Context, vendorID uuid.UUID, in MenuItemInput) (*MenuItem, error)
	UpdateMenuItem(ctx context.Context, vendorID, itemID uuid.UUID, in MenuItemInput) (*MenuItem, error)
	SetMenuItemAvailability(ctx context.Context, vendorID, itemID uuid.UUID, available bool) error
	DeleteMenuItem(ctx context.Context, vendorID, itemID uuid.UUID) error
}

type Postgres struct {
	Pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{Pool: pool}
}

const vendorCols = `id, name, station_code, subscription_tier::text, accept_mode::text, is_active,
	fssai_status, email, owner_name, stall_image_url`

func scanVendor(row interface{ Scan(dest ...any) error }) (*Vendor, error) {
	var v Vendor
	err := row.Scan(&v.ID, &v.Name, &v.StationCode, &v.SubscriptionTier, &v.AcceptMode, &v.IsActive,
		&v.FssaiStatus, &v.Email, &v.OwnerName, &v.StallImageURL)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &v, err
}

func (p *Postgres) GetByID(ctx context.Context, id uuid.UUID) (*Vendor, error) {
	row := p.Pool.QueryRow(ctx, `SELECT `+vendorCols+` FROM vendors WHERE id = $1`, id)
	return scanVendor(row)
}

func (p *Postgres) GetByEmail(ctx context.Context, email string) (*Vendor, error) {
	row := p.Pool.QueryRow(ctx, `SELECT `+vendorCols+` FROM vendors WHERE email = $1`, email)
	return scanVendor(row)
}

// Create inserts a new vendor shell (used at first login, before onboarding
// fills in stall name / station / accept mode via UpdateProfile).
func (p *Postgres) Create(ctx context.Context, v *Vendor) error {
	if v.Name == "" {
		v.Name = "New Merchant"
	}
	if v.SubscriptionTier == "" {
		v.SubscriptionTier = "level_1"
	}
	if v.AcceptMode == "" {
		v.AcceptMode = "manual"
	}
	return p.Pool.QueryRow(ctx, `
		INSERT INTO vendors (name, station_code, subscription_tier, accept_mode, email, owner_name)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, is_active, fssai_status
	`, v.Name, v.StationCode, v.SubscriptionTier, v.AcceptMode, v.Email, v.OwnerName,
	).Scan(&v.ID, &v.IsActive, &v.FssaiStatus)
}

// updatableVendorFields allow-lists which JSON keys UpdateProfile may write,
// so callers can pass a raw partial body straight through from the handler.
var updatableVendorFields = map[string]string{
	"name":              "name",
	"station_code":      "station_code",
	"owner_name":        "owner_name",
	"fssai_status":      "fssai_status",
	"accept_mode":       "accept_mode",
	"stall_image_url":   "stall_image_url",
	"subscription_tier": "subscription_tier",
}

func (p *Postgres) UpdateProfile(ctx context.Context, id uuid.UUID, fields map[string]any) (*Vendor, error) {
	set := ""
	args := []any{id}
	for k, v := range fields {
		col, ok := updatableVendorFields[k]
		if !ok {
			continue
		}
		args = append(args, v)
		if set != "" {
			set += ", "
		}
		set += col + " = $" + strconv.Itoa(len(args))
	}
	if set == "" {
		return p.GetByID(ctx, id)
	}
	tag, err := p.Pool.Exec(ctx, `UPDATE vendors SET `+set+` WHERE id = $1`, args...)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrNotFound
	}
	return p.GetByID(ctx, id)
}

func (p *Postgres) InsertOfflineSale(ctx context.Context, tx pgx.Tx, s *OfflineSale) error {
	return tx.QueryRow(ctx, `
		INSERT INTO offline_sales (vendor_id, amount_paise, qr_generated_at, payment_verified, provider_ref)
		VALUES ($1,$2,$3,FALSE,$4)
		RETURNING id
	`, s.VendorID, s.AmountPaise, s.QRGeneratedAt, s.ProviderRef).Scan(&s.ID)
}

func (p *Postgres) ConfirmOfflineSale(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	_, err := tx.Exec(ctx, `
		UPDATE offline_sales
		SET confirmed_at = now(), payment_verified = TRUE
		WHERE id = $1
	`, id)
	return err
}

func (p *Postgres) RecordTap(ctx context.Context, vendorID, customerID uuid.UUID) error {
	_, err := p.Pool.Exec(ctx, `
		INSERT INTO vendor_taps (vendor_id, customer_id)
		VALUES ($1, $2)
	`, vendorID, customerID)
	return err
}

const menuItemCols = `mi.id, mi.vendor_id, mi.name, mi.price_paise, mi.diet_type::text, mi.is_otc, mi.is_ten_min,
	mi.is_available, mi.dish_id, mi.selected_image_id, mi.image_source_note,
	di.image_url, mi.created_at`

func scanMenuItem(row interface{ Scan(dest ...any) error }) (*MenuItem, error) {
	var m MenuItem
	err := row.Scan(&m.ID, &m.VendorID, &m.Name, &m.PricePaise, &m.DietType, &m.IsOTC, &m.IsTenMin,
		&m.IsAvailable, &m.DishID, &m.SelectedImageID, &m.ImageSourceNote, &m.PhotoURL, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &m, err
}

func (p *Postgres) ListMenuItems(ctx context.Context, vendorID uuid.UUID) ([]MenuItem, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT `+menuItemCols+`
		FROM menu_items mi
		LEFT JOIN dish_images di ON di.id = mi.selected_image_id
		WHERE mi.vendor_id = $1
		ORDER BY mi.created_at ASC
	`, vendorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []MenuItem
	for rows.Next() {
		m, err := scanMenuItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *m)
	}
	return out, rows.Err()
}

func (p *Postgres) CreateMenuItem(ctx context.Context, vendorID uuid.UUID, in MenuItemInput) (*MenuItem, error) {
	var id uuid.UUID
	err := p.Pool.QueryRow(ctx, `
		INSERT INTO menu_items (vendor_id, name, price_paise, diet_type, is_otc, is_ten_min, dish_id, selected_image_id, image_source_note)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		RETURNING id
	`, vendorID, in.Name, in.PricePaise, dietOrDefault(in.DietType), in.IsOTC, in.IsTenMin, in.DishID, in.SelectedImageID, in.ImageSourceNote,
	).Scan(&id)
	if err != nil {
		return nil, err
	}
	return p.getMenuItem(ctx, vendorID, id)
}

func (p *Postgres) UpdateMenuItem(ctx context.Context, vendorID, itemID uuid.UUID, in MenuItemInput) (*MenuItem, error) {
	tag, err := p.Pool.Exec(ctx, `
		UPDATE menu_items
		SET name = $3, price_paise = $4, diet_type = $5, is_otc = $6, is_ten_min = $7,
		    dish_id = $8, selected_image_id = $9, image_source_note = $10
		WHERE id = $1 AND vendor_id = $2
	`, itemID, vendorID, in.Name, in.PricePaise, dietOrDefault(in.DietType), in.IsOTC, in.IsTenMin,
		in.DishID, in.SelectedImageID, in.ImageSourceNote)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrNotFound
	}
	return p.getMenuItem(ctx, vendorID, itemID)
}

func (p *Postgres) SetMenuItemAvailability(ctx context.Context, vendorID, itemID uuid.UUID, available bool) error {
	tag, err := p.Pool.Exec(ctx, `
		UPDATE menu_items SET is_available = $3 WHERE id = $1 AND vendor_id = $2
	`, itemID, vendorID, available)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (p *Postgres) DeleteMenuItem(ctx context.Context, vendorID, itemID uuid.UUID) error {
	tag, err := p.Pool.Exec(ctx, `DELETE FROM menu_items WHERE id = $1 AND vendor_id = $2`, itemID, vendorID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (p *Postgres) getMenuItem(ctx context.Context, vendorID, itemID uuid.UUID) (*MenuItem, error) {
	row := p.Pool.QueryRow(ctx, `
		SELECT `+menuItemCols+`
		FROM menu_items mi
		LEFT JOIN dish_images di ON di.id = mi.selected_image_id
		WHERE mi.id = $1 AND mi.vendor_id = $2
	`, itemID, vendorID)
	return scanMenuItem(row)
}

func dietOrDefault(d string) string {
	if d == "veg" || d == "non_veg" {
		return d
	}
	return "veg"
}
