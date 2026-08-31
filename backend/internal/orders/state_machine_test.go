package orders

import (
	"testing"
	"time"

	"github.com/locobite/backend/internal/config"
)

func TestCanTransition_AllPairs(t *testing.T) {
	all := []Status{
		StatusRequested, StatusAccepted, StatusPreparing, StatusReady,
		StatusOutForDelivery, StatusDelivered, StatusCancelled, StatusRejected,
		StatusDisputed, StatusRefunded, StatusResolvedRefunded, StatusResolvedRejected,
	}
	allowed := map[Status]map[Status]bool{
		StatusRequested: {
			StatusAccepted: true, StatusCancelled: true, StatusRejected: true,
		},
		StatusAccepted: {
			StatusPreparing: true, StatusCancelled: true, StatusRejected: true,
		},
		StatusPreparing:      {StatusReady: true},
		StatusReady:          {StatusOutForDelivery: true},
		StatusOutForDelivery: {StatusDelivered: true, StatusDisputed: true},
		StatusDelivered:      {StatusDisputed: true},
		StatusDisputed: {
			StatusResolvedRefunded: true, StatusResolvedRejected: true,
		},
	}

	for _, from := range all {
		for _, to := range all {
			want := allowed[from][to]
			got := CanTransition(from, to)
			if got != want {
				t.Errorf("CanTransition(%s -> %s) = %v, want %v", from, to, got, want)
			}
		}
	}
}

func TestCanReject(t *testing.T) {
	tests := []struct {
		name   string
		from   Status
		reason RejectionReason
		want   bool
	}{
		{"requested with reason", StatusRequested, ReasonOutOfStock, true},
		{"accepted with reason", StatusAccepted, ReasonTooBusy, true},
		{"requested missing reason", StatusRequested, "", false},
		{"requested invalid reason", StatusRequested, RejectionReason("nope"), false},
		{"preparing cannot reject", StatusPreparing, ReasonOther, false},
		{"ready cannot reject", StatusReady, ReasonClosingSoon, false},
		{"delivered cannot reject", StatusDelivered, ReasonOutOfStock, false},
		{"all valid reasons from requested", StatusRequested, ReasonClosingSoon, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := CanReject(tt.from, tt.reason); got != tt.want {
				t.Errorf("CanReject(%s, %s) = %v, want %v", tt.from, tt.reason, got, tt.want)
			}
		})
	}
}

func TestCanCancel(t *testing.T) {
	now := time.Date(2026, 8, 31, 10, 0, 0, 0, time.UTC)
	delay := now.Add(-time.Minute)

	tests := []struct {
		name string
		o    OrderView
		want bool
	}{
		{
			name: "requested within 15m no delay no ten-min",
			o:    OrderView{Status: StatusRequested, CreatedAt: now.Add(-10 * time.Minute)},
			want: true,
		},
		{
			name: "accepted within 15m",
			o:    OrderView{Status: StatusAccepted, CreatedAt: now.Add(-14 * time.Minute)},
			want: true,
		},
		{
			name: "exactly 15m is still valid",
			o:    OrderView{Status: StatusRequested, CreatedAt: now.Add(-config.CancelWindow)},
			want: true,
		},
		{
			name: "past 15m",
			o:    OrderView{Status: StatusRequested, CreatedAt: now.Add(-15*time.Minute - time.Second)},
			want: false,
		},
		{
			name: "delay chip tapped",
			o: OrderView{
				Status:         StatusRequested,
				CreatedAt:      now.Add(-2 * time.Minute),
				DelayUpdatedAt: &delay,
			},
			want: false,
		},
		{
			name: "ten min item never cancellable",
			o: OrderView{
				Status:        StatusRequested,
				CreatedAt:     now.Add(-1 * time.Minute),
				HasTenMinItem: true,
			},
			want: false,
		},
		{
			name: "preparing not cancellable",
			o:    OrderView{Status: StatusPreparing, CreatedAt: now.Add(-1 * time.Minute)},
			want: false,
		},
		{
			name: "out_for_delivery not cancellable",
			o:    OrderView{Status: StatusOutForDelivery, CreatedAt: now.Add(-1 * time.Minute)},
			want: false,
		},
		{
			name: "delivered not cancellable",
			o:    OrderView{Status: StatusDelivered, CreatedAt: now.Add(-1 * time.Minute)},
			want: false,
		},
		{
			name: "already cancelled",
			o:    OrderView{Status: StatusCancelled, CreatedAt: now.Add(-1 * time.Minute)},
			want: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := CanCancel(tt.o, now); got != tt.want {
				t.Errorf("CanCancel() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestShouldAutoAccept(t *testing.T) {
	now := time.Date(2026, 8, 31, 10, 0, 0, 0, time.UTC)
	tests := []struct {
		name   string
		status Status
		mode   AcceptMode
		age    time.Duration
		want   bool
	}{
		{"manual past timeout", StatusRequested, Manual, config.AutoAcceptTimeout + time.Second, true},
		{"manual exactly timeout", StatusRequested, Manual, config.AutoAcceptTimeout, true},
		{"manual before timeout", StatusRequested, Manual, config.AutoAcceptTimeout - time.Second, false},
		{"accept_all never auto via job", StatusRequested, AcceptAll, time.Hour, false},
		{"already accepted", StatusAccepted, Manual, time.Hour, false},
		{"already rejected", StatusRejected, Manual, time.Hour, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ShouldAutoAccept(tt.status, tt.mode, now.Add(-tt.age), now)
			if got != tt.want {
				t.Errorf("got %v want %v", got, tt.want)
			}
		})
	}
}

func TestImmediateAcceptOnCreate(t *testing.T) {
	if !ImmediateAcceptOnCreate(AcceptAll) {
		t.Fatal("accept_all should accept immediately")
	}
	if ImmediateAcceptOnCreate(Manual) {
		t.Fatal("manual should not accept immediately")
	}
}
