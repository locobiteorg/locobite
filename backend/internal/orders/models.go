package orders

import (
	"time"

	"github.com/google/uuid"
)

type Order struct {
	ID               uuid.UUID
	CustomerID       uuid.UUID
	VendorID         uuid.UUID
	Status           Status
	AmountPaise      int
	TrainNumber      string
	Direction        string
	SeatCoach        string
	ScheduledArrival time.Time
	DelayUpdatedAt   *time.Time
	RejectionReason  *RejectionReason
	PickupStatus     string
	HasTenMinItem    bool
	PaymentVerified  bool
	CreatedAt        time.Time
	UpdatedAt        time.Time
	Items            []LineItem
	// PenaltyPaise is the server-computed rejection penalty for this order,
	// if one was charged. Clients display it read-only; never recompute the
	// 75/25 split or the band on the client.
	PenaltyPaise *int
}

func (o Order) View() OrderView {
	return OrderView{
		Status:         o.Status,
		CreatedAt:      o.CreatedAt,
		DelayUpdatedAt: o.DelayUpdatedAt,
		HasTenMinItem:  o.HasTenMinItem,
	}
}

type LineItem struct {
	ID             uuid.UUID `json:"id"`
	OrderID        uuid.UUID `json:"order_id"`
	MenuItemID     uuid.UUID `json:"menu_item_id"`
	Name           string    `json:"name"`
	Quantity       int       `json:"quantity"`
	UnitPricePaise int       `json:"unit_price_paise"`
	IsTenMin       bool      `json:"is_ten_min"`
	// IsVeg is read from menu_items.diet_type at query time (order_items
	// itself doesn't store it), so clients can render a veg/non-veg dot.
	IsVeg bool `json:"is_veg"`
}

type MenuItem struct {
	ID         uuid.UUID
	VendorID   uuid.UUID
	Name       string
	PricePaise int
	IsTenMin   bool
}

type CreateInput struct {
	CustomerID       uuid.UUID
	VendorID         uuid.UUID
	TrainNumber      string
	Direction        string
	SeatCoach        string
	ScheduledArrival time.Time
	Items            []CreateItem
}

type CreateItem struct {
	MenuItemID uuid.UUID
	Quantity   int
}

type ListResult struct {
	Order       Order
	Reorderable bool
}
