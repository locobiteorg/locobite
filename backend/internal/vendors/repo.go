package vendors

import (
	"context"
	"errors"
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

type Repository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*Vendor, error)
	InsertOfflineSale(ctx context.Context, tx pgx.Tx, s *OfflineSale) error
	ConfirmOfflineSale(ctx context.Context, tx pgx.Tx, id uuid.UUID) error
	RecordTap(ctx context.Context, vendorID, customerID uuid.UUID) error
}

type Postgres struct {
	Pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{Pool: pool}
}

func (p *Postgres) GetByID(ctx context.Context, id uuid.UUID) (*Vendor, error) {
	var v Vendor
	err := p.Pool.QueryRow(ctx, `
		SELECT id, name, station_code, subscription_tier::text, accept_mode::text, is_active
		FROM vendors WHERE id = $1
	`, id).Scan(&v.ID, &v.Name, &v.StationCode, &v.SubscriptionTier, &v.AcceptMode, &v.IsActive)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &v, err
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
