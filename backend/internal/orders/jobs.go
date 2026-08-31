package orders

import (
	"context"
	"log"
	"time"

	"github.com/locobite/backend/internal/config"
)

// AutoAcceptJob scans requested orders past AUTO_ACCEPT_TIMEOUT whose vendor
// is in manual mode and transitions them to accepted. Vendor inaction never
// auto-rejects.
func (h *Handler) AutoAcceptJob(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = 15 * time.Second
	}
	t := time.NewTicker(interval)
	defer t.Stop()
	h.runAutoAccept(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			h.runAutoAccept(ctx)
		}
	}
}

func (h *Handler) runAutoAccept(ctx context.Context) {
	cutoff := time.Now().UTC().Add(-config.AutoAcceptTimeout)
	list, err := h.Orders.ListRequestedForAutoAccept(ctx, cutoff)
	if err != nil {
		log.Printf("auto-accept list: %v", err)
		return
	}
	for _, o := range list {
		if !ShouldAutoAccept(o.Status, Manual, o.CreatedAt, time.Now().UTC()) {
			continue
		}
		tx, err := h.Pool.Begin(ctx)
		if err != nil {
			log.Printf("auto-accept begin: %v", err)
			continue
		}
		if err := h.Orders.UpdateStatus(ctx, tx, o.ID, StatusAccepted, nil); err != nil {
			_ = tx.Rollback(ctx)
			log.Printf("auto-accept update %s: %v", o.ID, err)
			continue
		}
		if err := tx.Commit(ctx); err != nil {
			log.Printf("auto-accept commit %s: %v", o.ID, err)
		}
	}
}
