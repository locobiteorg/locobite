package customers

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/locobite/backend/internal/config"
)

var ErrNotFound = errors.New("not found")
var ErrHasDues = errors.New("customer has outstanding dues")

type Customer struct {
	ID               uuid.UUID
	Phone            string
	Name             string
	DuesBalancePaise int
	IsBlockedForDues bool
	DeletedAt        *time.Time
}

type DueEntry struct {
	ID               uuid.UUID
	CustomerID       uuid.UUID
	AmountPaise      int
	Reason           string
	AppliedToOrderID *uuid.UUID
	Status           string
	CreatedAt        time.Time
}

type Repository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*Customer, error)
	GetByPhone(ctx context.Context, phone string) (*Customer, error)
	Create(ctx context.Context, c *Customer) error
	ApplyOldestPendingDue(ctx context.Context, tx pgx.Tx, customerID, orderID uuid.UUID) (*DueEntry, error)
	AddPendingDue(ctx context.Context, tx pgx.Tx, customerID uuid.UUID, amountPaise int, reason string) error
	ClearPendingDues(ctx context.Context, tx pgx.Tx, customerID uuid.UUID) (int, error)
	CountDisputesByPhone(ctx context.Context, phone string, since time.Time) (int, error)
	CountVendorDisputes(ctx context.Context, vendorID uuid.UUID, since time.Time) (int, error)
	CountVendorRejections(ctx context.Context, vendorID uuid.UUID, since time.Time) (int, error)
	InsertDispute(ctx context.Context, tx pgx.Tx, orderID, customerID, vendorID uuid.UUID, dtype string, refundPaise int) (uuid.UUID, error)
	InsertVendorDisputeLog(ctx context.Context, tx pgx.Tx, vendorID, disputeID uuid.UUID) error
	InsertPenalty(ctx context.Context, tx pgx.Tx, vendorID, orderID uuid.UUID, reason string, amount, customerShare, platformShare int) error
	SoftDelete(ctx context.Context, tx pgx.Tx, id uuid.UUID) error
}

type Postgres struct {
	Pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{Pool: pool}
}

func (p *Postgres) GetByID(ctx context.Context, id uuid.UUID) (*Customer, error) {
	var c Customer
	err := p.Pool.QueryRow(ctx, `
		SELECT id, phone, name, dues_balance_paise, is_blocked_for_dues, deleted_at
		FROM customers WHERE id = $1
	`, id).Scan(&c.ID, &c.Phone, &c.Name, &c.DuesBalancePaise, &c.IsBlockedForDues, &c.DeletedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &c, err
}

func (p *Postgres) GetByPhone(ctx context.Context, phone string) (*Customer, error) {
	var c Customer
	err := p.Pool.QueryRow(ctx, `
		SELECT id, phone, name, dues_balance_paise, is_blocked_for_dues, deleted_at
		FROM customers WHERE phone = $1
	`, phone).Scan(&c.ID, &c.Phone, &c.Name, &c.DuesBalancePaise, &c.IsBlockedForDues, &c.DeletedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &c, err
}

func (p *Postgres) Create(ctx context.Context, c *Customer) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	_, err := p.Pool.Exec(ctx, `
		INSERT INTO customers (id, phone, name)
		VALUES ($1, $2, $3)
	`, c.ID, c.Phone, c.Name)
	return err
}

func (p *Postgres) ApplyOldestPendingDue(ctx context.Context, tx pgx.Tx, customerID, orderID uuid.UUID) (*DueEntry, error) {
	var e DueEntry
	err := tx.QueryRow(ctx, `
		SELECT id, customer_id, amount_paise, reason, applied_to_order_id, status, created_at
		FROM customer_dues_ledger
		WHERE customer_id = $1 AND status = 'pending'
		ORDER BY created_at ASC
		LIMIT 1
		FOR UPDATE
	`, customerID).Scan(&e.ID, &e.CustomerID, &e.AmountPaise, &e.Reason, &e.AppliedToOrderID, &e.Status, &e.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	_, err = tx.Exec(ctx, `
		UPDATE customer_dues_ledger
		SET status = 'applied', applied_to_order_id = $2
		WHERE id = $1
	`, e.ID, orderID)
	if err != nil {
		return nil, err
	}
	_, err = tx.Exec(ctx, `
		UPDATE customers
		SET dues_balance_paise = GREATEST(dues_balance_paise - $2, 0),
		    is_blocked_for_dues = CASE
		        WHEN GREATEST(dues_balance_paise - $2, 0) >= $3 THEN TRUE
		        ELSE FALSE
		    END
		WHERE id = $1
	`, customerID, e.AmountPaise, config.DuesBlockCapPaise)
	if err != nil {
		return nil, err
	}
	e.Status = "applied"
	e.AppliedToOrderID = &orderID
	return &e, nil
}

func (p *Postgres) AddPendingDue(ctx context.Context, tx pgx.Tx, customerID uuid.UUID, amountPaise int, reason string) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO customer_dues_ledger (customer_id, amount_paise, reason, status)
		VALUES ($1, $2, $3, 'pending')
	`, customerID, amountPaise, reason)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		UPDATE customers
		SET dues_balance_paise = dues_balance_paise + $2,
		    is_blocked_for_dues = CASE
		        WHEN dues_balance_paise + $2 >= $3 THEN TRUE
		        ELSE is_blocked_for_dues
		    END
		WHERE id = $1
	`, customerID, amountPaise, config.DuesBlockCapPaise)
	return err
}

func (p *Postgres) ClearPendingDues(ctx context.Context, tx pgx.Tx, customerID uuid.UUID) (int, error) {
	var total int
	err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount_paise), 0)
		FROM customer_dues_ledger
		WHERE customer_id = $1 AND status = 'pending'
	`, customerID).Scan(&total)
	if err != nil {
		return 0, err
	}
	_, err = tx.Exec(ctx, `
		UPDATE customer_dues_ledger SET status = 'cleared'
		WHERE customer_id = $1 AND status = 'pending'
	`, customerID)
	if err != nil {
		return 0, err
	}
	_, err = tx.Exec(ctx, `
		UPDATE customers SET dues_balance_paise = 0, is_blocked_for_dues = FALSE
		WHERE id = $1
	`, customerID)
	return total, err
}

func (p *Postgres) CountDisputesByPhone(ctx context.Context, phone string, since time.Time) (int, error) {
	var n int
	err := p.Pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM disputes d
		JOIN customers c ON c.id = d.customer_id
		WHERE c.phone = $1 AND d.created_at >= $2
	`, phone, since).Scan(&n)
	return n, err
}

func (p *Postgres) CountVendorDisputes(ctx context.Context, vendorID uuid.UUID, since time.Time) (int, error) {
	var n int
	err := p.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM vendor_disputes
		WHERE vendor_id = $1 AND created_at >= $2
	`, vendorID, since).Scan(&n)
	return n, err
}

func (p *Postgres) CountVendorRejections(ctx context.Context, vendorID uuid.UUID, since time.Time) (int, error) {
	var n int
	err := p.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM orders
		WHERE vendor_id = $1 AND status = 'rejected' AND updated_at >= $2
	`, vendorID, since).Scan(&n)
	return n, err
}

func (p *Postgres) InsertDispute(ctx context.Context, tx pgx.Tx, orderID, customerID, vendorID uuid.UUID, dtype string, refundPaise int) (uuid.UUID, error) {
	var id uuid.UUID
	err := tx.QueryRow(ctx, `
		INSERT INTO disputes (order_id, customer_id, vendor_id, type, status, refund_tier_paise)
		VALUES ($1,$2,$3,$4,'open',$5)
		RETURNING id
	`, orderID, customerID, vendorID, dtype, refundPaise).Scan(&id)
	return id, err
}

func (p *Postgres) InsertVendorDisputeLog(ctx context.Context, tx pgx.Tx, vendorID, disputeID uuid.UUID) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO vendor_disputes (vendor_id, dispute_id) VALUES ($1, $2)
	`, vendorID, disputeID)
	return err
}

func (p *Postgres) InsertPenalty(ctx context.Context, tx pgx.Tx, vendorID, orderID uuid.UUID, reason string, amount, customerShare, platformShare int) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO vendor_penalties (vendor_id, order_id, reason, amount_paise, customer_share_paise, platform_share_paise)
		VALUES ($1,$2,$3,$4,$5,$6)
	`, vendorID, orderID, reason, amount, customerShare, platformShare)
	return err
}

func (p *Postgres) SoftDelete(ctx context.Context, tx pgx.Tx, id uuid.UUID) error {
	tag, err := tx.Exec(ctx, `
		UPDATE customers
		SET deleted_at = now(),
		    name = 'Deleted User',
		    phone = 'deleted:' || id::text
		WHERE id = $1 AND deleted_at IS NULL
	`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
