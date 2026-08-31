package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/locobite/backend/internal/customers"
	"github.com/locobite/backend/internal/db"
	"github.com/locobite/backend/internal/httperr"
	"github.com/locobite/backend/internal/orders"
	"github.com/locobite/backend/internal/payments"
	"github.com/locobite/backend/internal/vendors"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}
	apiKey := os.Getenv("PAYMENT_PROVIDER_API_KEY")
	webhookSecret := os.Getenv("WEBHOOK_SECRET")
	orders.SetWebhookSecret(webhookSecret)

	pool, err := db.NewPool(ctx, databaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	orderRepo := orders.NewPostgres(pool)
	custRepo := customers.NewPostgres(pool)
	vendorRepo := vendors.NewPostgres(pool)
	payRepo := payments.NewPostgres(pool)
	provider := &payments.StubProvider{APIKey: apiKey}

	oh := &orders.Handler{
		Pool:      pool,
		Orders:    orderRepo,
		Customers: custRepo,
		Vendors:   vendorRepo,
		Payments:  payRepo,
		Provider:  provider,
	}
	ch := &customers.Handler{Pool: pool, Repo: custRepo, Provider: provider}
	vh := &vendors.Handler{Pool: pool, Repo: vendorRepo, Payments: payRepo, Provider: provider}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		httperr.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	oh.Routes(r)
	ch.Routes(r)
	vh.Routes(r)

	go oh.AutoAcceptJob(ctx, 15*time.Second)

	addr := os.Getenv("ADDR")
	if addr == "" {
		port := os.Getenv("PORT")
		if port != "" {
			addr = ":" + port
		} else {
			addr = ":8080"
		}
	}
	srv := &http.Server{Addr: addr, Handler: r}
	go func() {
		log.Printf("listening on %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	<-ctx.Done()
	shut, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shut)
}
