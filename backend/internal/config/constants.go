package config

import "time"

// All numeric policy constants live here. Do not scatter magic numbers in handlers.

const (
	// AutoAcceptTimeout is how long a vendor in manual accept mode may wait
	// before the platform auto-ACCEPTS (never auto-rejects) a requested order.
	AutoAcceptTimeout = 150 * time.Second // 2.5 minutes

	// CancelWindow is the customer-initiated cancel window from created_at.
	CancelWindow = 15 * time.Minute

	// DisputeWindow is how long after QR generation a dispute may be filed.
	DisputeWindow = 30 * time.Minute

	// RollingWindow is used for dispute waivers, vendor dispute caps, and
	// free rejection allowances.
	RollingWindow = 5 * 24 * time.Hour
	RollingWindowDays = 5

	FreeDisputesPerWindow       = 3
	VendorDisputeCapPerWindow   = 3
	FreeRejectionsPerWindow     = 3

	PenaltyCustomerSharePercent = 75
	PenaltyPlatformSharePercent = 25

	// DuesBlockCapPaise: customers whose pending dues reach this are blocked
	// from placing new orders until they hit POST /customers/{id}/clear-dues.
	DuesBlockCapPaise = 50000 // TODO: confirm cap with product/finance
)

// RefundTierPaise returns the flat customer refund for a dispute on an order
// of the given amount. Both dispute types use the same tiers.
func RefundTierPaise(amountPaise int) int {
	switch {
	case amountPaise < 5000:
		return 500
	case amountPaise < 10000:
		return 1000
	case amountPaise < 30000:
		return 4000
	case amountPaise < 60000:
		return 6000
	case amountPaise < 100000:
		return 12000
	default:
		return 12000 // TODO: confirm handling for orders >= ₹1000
	}
}

// RejectionPenaltyPaise is steeper than dispute refunds (~1.7–2x).
func RejectionPenaltyPaise(amountPaise int) int {
	switch {
	case amountPaise < 5000:
		return 1500
	case amountPaise < 10000:
		return 2500
	case amountPaise < 30000:
		return 7500
	case amountPaise < 60000:
		return 12000
	case amountPaise < 100000:
		return 20000
	default:
		return 20000 // TODO: confirm handling for orders >= ₹1000
	}
}

func SplitPenalty(amountPaise int) (customerShare, platformShare int) {
	customerShare = amountPaise * PenaltyCustomerSharePercent / 100
	platformShare = amountPaise - customerShare
	return
}
