package orders

import (
	"time"

	"github.com/google/uuid"
)

type Order struct {
	ID              uuid.UUID
	CustomerID      uuid.UUID
	VendorID        uuid.UUID
	Status          Status
	AmountPaise     int
	TrainNumber     string
	Direction       string
	SeatCoach       string
	ScheduledArrival time.Time
	DelayUpdatedAt  *time.Time
	RejectionReason *RejectionReason
	PickupStatus    string
	HasTenMinItem   bool
	PaymentVerified bool
	CreatedAt       time.Time
	UpdatedAt       time.Time
	Items           []LineItem
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
	ID             uuid.UUID
	OrderID        uuid.UUID
	MenuItemID     uuid.UUID
	Name           string
	Quantity       int
	UnitPricePaise int
	IsTenMin       bool
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
