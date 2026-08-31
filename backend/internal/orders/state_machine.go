package orders

import (
	"time"

	"github.com/locobite/backend/internal/config"
)

type Status string

const (
	StatusRequested       Status = "requested"
	StatusAccepted        Status = "accepted"
	StatusPreparing       Status = "preparing"
	StatusReady           Status = "ready"
	StatusOutForDelivery  Status = "out_for_delivery"
	StatusDelivered       Status = "delivered"
	StatusCancelled       Status = "cancelled"
	StatusRejected        Status = "rejected"
	StatusDisputed        Status = "disputed"
	StatusRefunded        Status = "refunded"
	StatusResolvedRefunded Status = "resolved_refunded"
	StatusResolvedRejected Status = "resolved_rejected"
)

type RejectionReason string

const (
	ReasonOutOfStock  RejectionReason = "out_of_stock"
	ReasonTooBusy     RejectionReason = "too_busy"
	ReasonClosingSoon RejectionReason = "closing_soon"
	ReasonOther       RejectionReason = "other"
)

func ValidRejectionReason(r RejectionReason) bool {
	switch r {
	case ReasonOutOfStock, ReasonTooBusy, ReasonClosingSoon, ReasonOther:
		return true
	default:
		return false
	}
}

type AcceptMode string

const (
	AcceptAll AcceptMode = "accept_all"
	Manual    AcceptMode = "manual"
)

// OrderView is the subset of order fields the state machine needs.
// No DB types here — callers map from persistence.
type OrderView struct {
	Status         Status
	CreatedAt      time.Time
	DelayUpdatedAt *time.Time
	HasTenMinItem  bool
}

// CanTransition reports whether from -> to is a legal status change.
// Rejection is modeled separately because it requires a reason.
func CanTransition(from, to Status) bool {
	switch from {
	case StatusRequested:
		return to == StatusAccepted || to == StatusCancelled || to == StatusRejected
	case StatusAccepted:
		return to == StatusPreparing || to == StatusCancelled || to == StatusRejected
	case StatusPreparing:
		return to == StatusReady
	case StatusReady:
		return to == StatusOutForDelivery
	case StatusOutForDelivery:
		return to == StatusDelivered || to == StatusDisputed
	case StatusDelivered:
		return to == StatusDisputed
	case StatusDisputed:
		return to == StatusResolvedRefunded || to == StatusResolvedRejected
	default:
		return false
	}
}

func CanReject(from Status, reason RejectionReason) bool {
	if !ValidRejectionReason(reason) {
		return false
	}
	return from == StatusRequested || from == StatusAccepted
}

func CanCancel(o OrderView, now time.Time) bool {
	if o.Status != StatusRequested && o.Status != StatusAccepted {
		return false
	}
	if o.HasTenMinItem {
		return false
	}
	if o.DelayUpdatedAt != nil {
		return false
	}
	if now.Sub(o.CreatedAt) > config.CancelWindow {
		return false
	}
	return true
}

func ShouldAutoAccept(status Status, vendorMode AcceptMode, createdAt, now time.Time) bool {
	if status != StatusRequested {
		return false
	}
	if vendorMode != Manual {
		return false
	}
	return now.Sub(createdAt) >= config.AutoAcceptTimeout
}

func ImmediateAcceptOnCreate(vendorMode AcceptMode) bool {
	return vendorMode == AcceptAll
}
