package payments

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")
var ErrDuplicateEvent = errors.New("duplicate webhook event")

type Event struct {
	ID                uuid.UUID
	OrderID           *uuid.UUID
	OfflineSaleID     *uuid.UUID
	Type              string
	QRGeneratedAt     *time.Time
	ConfirmedAt       *time.Time
	AmountPaise       int
	RawWebhookPayload []byte
	ProviderEventID   *string
	ProviderRef       *string
}

type Repository interface {
	InsertQR(ctx context.Context, tx pgx.Tx, e *Event) error
	InsertCash(ctx context.Context, tx pgx.Tx, orderID uuid.UUID, amountPaise int) error
	LatestQRForOrder(ctx context.Context, orderID uuid.UUID) (*Event, error)
	GetByProviderRef(ctx context.Context, ref string) (*Event, error)
	ConfirmUPI(ctx context.Context, tx pgx.Tx, eventID uuid.UUID, providerEventID string, payload []byte) error
	ProviderEventExists(ctx context.Context, providerEventID string) (bool, error)
}

type Postgres struct {
	Pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{Pool: pool}
}

func (p *Postgres) InsertQR(ctx context.Context, tx pgx.Tx, e *Event) error {
	return tx.QueryRow(ctx, `
		INSERT INTO payment_events (order_id, offline_sale_id, type, qr_generated_at, amount_paise, provider_ref)
		VALUES ($1,$2,'qr_generated',$3,$4,$5)
		RETURNING id
	`, e.OrderID, e.OfflineSaleID, e.QRGeneratedAt, e.AmountPaise, e.ProviderRef).Scan(&e.ID)
}

func (p *Postgres) InsertCash(ctx context.Context, tx pgx.Tx, orderID uuid.UUID, amountPaise int) error {
	now := time.Now().UTC()
	_, err := tx.Exec(ctx, `
		INSERT INTO payment_events (order_id, type, confirmed_at, amount_paise)
		VALUES ($1, 'cash_confirmed', $2, $3)
	`, orderID, now, amountPaise)
	return err
}

func (p *Postgres) LatestQRForOrder(ctx context.Context, orderID uuid.UUID) (*Event, error) {
	e := &Event{}
	err := p.Pool.QueryRow(ctx, `
		SELECT id, order_id, offline_sale_id, type, qr_generated_at, confirmed_at, amount_paise,
		       raw_webhook_payload, provider_event_id, provider_ref
		FROM payment_events
		WHERE order_id = $1 AND qr_generated_at IS NOT NULL
		ORDER BY qr_generated_at DESC
		LIMIT 1
	`, orderID).Scan(&e.ID, &e.OrderID, &e.OfflineSaleID, &e.Type, &e.QRGeneratedAt, &e.ConfirmedAt,
		&e.AmountPaise, &e.RawWebhookPayload, &e.ProviderEventID, &e.ProviderRef)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return e, err
}

func (p *Postgres) GetByProviderRef(ctx context.Context, ref string) (*Event, error) {
	e := &Event{}
	err := p.Pool.QueryRow(ctx, `
		SELECT id, order_id, offline_sale_id, type, qr_generated_at, confirmed_at, amount_paise,
		       raw_webhook_payload, provider_event_id, provider_ref
		FROM payment_events
		WHERE provider_ref = $1
		ORDER BY qr_generated_at DESC NULLS LAST
		LIMIT 1
	`, ref).Scan(&e.ID, &e.OrderID, &e.OfflineSaleID, &e.Type, &e.QRGeneratedAt, &e.ConfirmedAt,
		&e.AmountPaise, &e.RawWebhookPayload, &e.ProviderEventID, &e.ProviderRef)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return e, err
}

func (p *Postgres) ConfirmUPI(ctx context.Context, tx pgx.Tx, eventID uuid.UUID, providerEventID string, payload []byte) error {
	if payload == nil {
		payload = []byte("{}")
	}
	if !json.Valid(payload) {
		payload = []byte("{}")
	}
	tag, err := tx.Exec(ctx, `
		UPDATE payment_events
		SET type = 'upi_confirmed',
		    confirmed_at = now(),
		    provider_event_id = $2,
		    raw_webhook_payload = $3
		WHERE id = $1 AND provider_event_id IS NULL
	`, eventID, providerEventID, payload)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrDuplicateEvent
		}
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrDuplicateEvent
	}
	return nil
}

func (p *Postgres) ProviderEventExists(ctx context.Context, providerEventID string) (bool, error) {
	var n int
	err := p.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM payment_events WHERE provider_event_id = $1
	`, providerEventID).Scan(&n)
	return n > 0, err
}

func isUniqueViolation(err error) bool {
	var pe interface{ SQLState() string }
	return errors.As(err, &pe) && pe.SQLState() == "23505"
}
