package orders

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

type Repository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*Order, error)
	GetItems(ctx context.Context, orderID uuid.UUID) ([]LineItem, error)
	GetMenuItems(ctx context.Context, ids []uuid.UUID) ([]MenuItem, error)
	Create(ctx context.Context, tx pgx.Tx, o *Order) error
	UpdateStatus(ctx context.Context, tx pgx.Tx, id uuid.UUID, status Status, reason *RejectionReason) error
	UpdateDelay(ctx context.Context, tx pgx.Tx, id uuid.UUID, at time.Time) error
	SetPaymentVerified(ctx context.Context, tx pgx.Tx, id uuid.UUID, verified bool) error
	AddToAmount(ctx context.Context, tx pgx.Tx, id uuid.UUID, paise int) error
	ListByCustomer(ctx context.Context, customerID uuid.UUID, limit, offset int) ([]Order, error)
	ListRequestedForAutoAccept(ctx context.Context, olderThan time.Time) ([]Order, error)
	VendorAcceptMode(ctx context.Context, vendorID uuid.UUID) (AcceptMode, error)
}

type Postgres struct {
	Pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{Pool: pool}
}

func (p *Postgres) GetByID(ctx context.Context, id uuid.UUID) (*Order, error) {
	row := p.Pool.QueryRow(ctx, `
		SELECT id, customer_id, vendor_id, status, amount_paise, train_number, direction,
		       seat_coach, scheduled_arrival, delay_updated_at, rejection_reason, pickup_status,
		       has_ten_min_item, payment_verified, created_at, updated_at
		FROM orders WHERE id = $1
	`, id)
	o, err := scanOrder(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	items, err := p.GetItems(ctx, id)
	if err != nil {
		return nil, err
	}
	o.Items = items
	return o, nil
}

func (p *Postgres) GetItems(ctx context.Context, orderID uuid.UUID) ([]LineItem, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT id, order_id, menu_item_id, name, quantity, unit_price_paise, is_ten_min
		FROM order_items WHERE order_id = $1
	`, orderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []LineItem
	for rows.Next() {
		var it LineItem
		if err := rows.Scan(&it.ID, &it.OrderID, &it.MenuItemID, &it.Name, &it.Quantity, &it.UnitPricePaise, &it.IsTenMin); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (p *Postgres) GetMenuItems(ctx context.Context, ids []uuid.UUID) ([]MenuItem, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := p.Pool.Query(ctx, `
		SELECT id, vendor_id, name, price_paise, is_ten_min
		FROM menu_items WHERE id = ANY($1)
	`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []MenuItem
	for rows.Next() {
		var m MenuItem
		if err := rows.Scan(&m.ID, &m.VendorID, &m.Name, &m.PricePaise, &m.IsTenMin); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (p *Postgres) Create(ctx context.Context, tx pgx.Tx, o *Order) error {
	err := tx.QueryRow(ctx, `
		INSERT INTO orders (
			customer_id, vendor_id, status, amount_paise, train_number, direction,
			seat_coach, scheduled_arrival, has_ten_min_item
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		RETURNING id, created_at, updated_at, pickup_status, payment_verified
	`, o.CustomerID, o.VendorID, o.Status, o.AmountPaise, o.TrainNumber, o.Direction,
		o.SeatCoach, o.ScheduledArrival, o.HasTenMinItem,
	).Scan(&o.ID, &o.CreatedAt, &o.UpdatedAt, &o.PickupStatus, &o.PaymentVerified)
	if err != nil {
		return fmt.Errorf("insert order: %w", err)
	}
	for i := range o.Items {
		it := &o.Items[i]
		it.OrderID = o.ID
		err := tx.QueryRow(ctx, `
			INSERT INTO order_items (order_id, menu_item_id, name, quantity, unit_price_paise, is_ten_min)
			VALUES ($1,$2,$3,$4,$5,$6) RETURNING id
		`, o.ID, it.MenuItemID, it.Name, it.Quantity, it.UnitPricePaise, it.IsTenMin,
		).Scan(&it.ID)
		if err != nil {
			return fmt.Errorf("insert order item: %w", err)
		}
	}
	return nil
}

func (p *Postgres) UpdateStatus(ctx context.Context, tx pgx.Tx, id uuid.UUID, status Status, reason *RejectionReason) error {
	tag, err := tx.Exec(ctx, `
		UPDATE orders SET status = $2, rejection_reason = $3, updated_at = now()
		WHERE id = $1
	`, id, status, reason)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (p *Postgres) UpdateDelay(ctx context.Context, tx pgx.Tx, id uuid.UUID, at time.Time) error {
	tag, err := tx.Exec(ctx, `
		UPDATE orders SET delay_updated_at = $2, updated_at = now() WHERE id = $1
	`, id, at)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (p *Postgres) SetPaymentVerified(ctx context.Context, tx pgx.Tx, id uuid.UUID, verified bool) error {
	_, err := tx.Exec(ctx, `
		UPDATE orders SET payment_verified = $2, updated_at = now() WHERE id = $1
	`, id, verified)
	return err
}

func (p *Postgres) AddToAmount(ctx context.Context, tx pgx.Tx, id uuid.UUID, paise int) error {
	_, err := tx.Exec(ctx, `
		UPDATE orders SET amount_paise = amount_paise + $2, updated_at = now() WHERE id = $1
	`, id, paise)
	return err
}

func (p *Postgres) ListByCustomer(ctx context.Context, customerID uuid.UUID, limit, offset int) ([]Order, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT id, customer_id, vendor_id, status, amount_paise, train_number, direction,
		       seat_coach, scheduled_arrival, delay_updated_at, rejection_reason, pickup_status,
		       has_ten_min_item, payment_verified, created_at, updated_at
		FROM orders
		WHERE customer_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, customerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Order
	for rows.Next() {
		o, err := scanOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *o)
	}
	return out, rows.Err()
}

func (p *Postgres) ListRequestedForAutoAccept(ctx context.Context, olderThan time.Time) ([]Order, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT o.id, o.customer_id, o.vendor_id, o.status, o.amount_paise, o.train_number, o.direction,
		       o.seat_coach, o.scheduled_arrival, o.delay_updated_at, o.rejection_reason, o.pickup_status,
		       o.has_ten_min_item, o.payment_verified, o.created_at, o.updated_at
		FROM orders o
		JOIN vendors v ON v.id = o.vendor_id
		WHERE o.status = 'requested'
		  AND v.accept_mode = 'manual'
		  AND o.created_at <= $1
	`, olderThan)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Order
	for rows.Next() {
		o, err := scanOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *o)
	}
	return out, rows.Err()
}

func (p *Postgres) VendorAcceptMode(ctx context.Context, vendorID uuid.UUID) (AcceptMode, error) {
	var mode string
	err := p.Pool.QueryRow(ctx, `SELECT accept_mode FROM vendors WHERE id = $1`, vendorID).Scan(&mode)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", err
	}
	return AcceptMode(mode), nil
}

type scanner interface {
	Scan(dest ...any) error
}

func scanOrder(row scanner) (*Order, error) {
	var o Order
	var reason *string
	err := row.Scan(
		&o.ID, &o.CustomerID, &o.VendorID, &o.Status, &o.AmountPaise, &o.TrainNumber, &o.Direction,
		&o.SeatCoach, &o.ScheduledArrival, &o.DelayUpdatedAt, &reason, &o.PickupStatus,
		&o.HasTenMinItem, &o.PaymentVerified, &o.CreatedAt, &o.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	if reason != nil {
		r := RejectionReason(*reason)
		o.RejectionReason = &r
	}
	return &o, nil
}
