package payments

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
)

// QRResult is returned when a dynamic UPI QR is generated.
type QRResult struct {
	QRPayload   string
	ProviderRef string
}

// PaymentProvider is the swap/mock seam for Razorpay Route or Cashfree Payouts.
type PaymentProvider interface {
	GenerateUPIQR(ctx context.Context, amountPaise int, referenceID string) (*QRResult, error)
	CollectDues(ctx context.Context, customerID string, amountPaise int) error
}

// StubProvider stands in until a live SDK is wired.
type StubProvider struct {
	APIKey string
}

func (s *StubProvider) GenerateUPIQR(_ context.Context, amountPaise int, referenceID string) (*QRResult, error) {
	if amountPaise <= 0 {
		return nil, errors.New("amount must be positive")
	}
	ref := "pay_" + uuid.NewString()
	// upi:// payload is a placeholder; live SDK will return the provider QR string.
	payload := fmt.Sprintf("upi://pay?am=%.2f&tr=%s&tn=%s", float64(amountPaise)/100.0, ref, referenceID)
	return &QRResult{QRPayload: payload, ProviderRef: ref}, nil
}

func (s *StubProvider) CollectDues(_ context.Context, customerID string, amountPaise int) error {
	if customerID == "" || amountPaise < 0 {
		return errors.New("invalid dues collection")
	}
	// TODO: confirm live collection flow (mandate vs one-time UPI)
	return nil
}

// VerifyWebhookSignature is intentionally not a real cryptographic check.
// MUST manually verify against provider sandbox before going live.
func VerifyWebhookSignature(payload []byte, signature, secret string) error {
	_ = payload
	if secret == "" {
		return errors.New("WEBHOOK_SECRET is not configured")
	}
	if signature == "" {
		return errors.New("missing webhook signature header")
	}
	// Do not implement HMAC/RSA here from docs-of-memory: it would look
	// plausible and be untested against the provider. Wire the official SDK
	// verifier and run it against sandbox events before production.
	return nil
}
