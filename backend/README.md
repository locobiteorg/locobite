# LocoBite backend

Go service for stateful / money-touching operations (orders, payments, disputes, dues, offline sales, account deletion). Read-only discovery (`menu_items`, `train_routes`, `route_stations`) stays on Supabase Auth + RLS — this service does not expose those endpoints.

## Environment

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Postgres connection string (Supabase or local). Example: `postgres://postgres:postgres@localhost:5432/locobite?sslmode=disable` |
| `PAYMENT_PROVIDER_API_KEY` | API key for Razorpay Route / Cashfree (stubbed today via `payments.PaymentProvider`) |
| `WEBHOOK_SECRET` | Shared secret for `POST /webhooks/payment`. Signature verification is **stubbed** — must be wired to the provider SDK and tested against sandbox before going live |
| `ADDR` | Optional listen address (default `:8080`) |

## Migrations + seed

From this directory:

```bash
export DATABASE_URL='postgres://postgres:postgres@localhost:5432/locobite?sslmode=disable'

go run ./cmd/migrate up
go run ./cmd/seed
```

Roll back one version with `go run ./cmd/migrate down`.

You can also use the [golang-migrate CLI](https://github.com/golang-migrate/migrate) against `./migrations`.

## Run the API

```bash
export DATABASE_URL='...'
export PAYMENT_PROVIDER_API_KEY='dev'
export WEBHOOK_SECRET='dev-secret'
go run ./cmd/server
```

Auto-accept job: goroutine + ticker; vendors in `manual` mode have requested orders accepted after 2.5 minutes (never auto-rejected).

## Endpoints

Errors are always `{"error":"...","code":"..."}`.

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Liveness |
| POST | `/orders` | Create order (validates menu items, applies **one** FIFO pending due) |
| POST | `/orders/{id}/accept` | Vendor accept |
| POST | `/orders/{id}/reject` | Body `{ "reason": "out_of_stock\|too_busy\|closing_soon\|other" }` |
| POST | `/orders/{id}/cancel` | Customer cancel (15m window, no delay chip, no 10-min items) |
| POST | `/orders/{id}/preparing` | Happy-path advance |
| POST | `/orders/{id}/ready` | |
| POST | `/orders/{id}/out-for-delivery` | |
| POST | `/orders/{id}/delivered` | |
| PATCH | `/orders/{id}/delay` | Body `{ "chip": "+15\|+30\|on-time" }` — sets `delay_updated_at`, kills cancellability |
| GET | `/customers/{id}/orders` | `?limit=&offset=` — includes `reorderable` |
| POST | `/orders/{id}/reorder` | Pre-filled cart from line items |
| POST | `/orders/{id}/collect-payment` | UPI QR from `order.amount_paise` (never from body) |
| POST | `/orders/{id}/cash-received` | Self-reported cash — **not** Trusted Vendor verified |
| POST | `/webhooks/payment` | Header `X-Webhook-Signature`. Body `{ "event_id", "provider_ref", "status" }`. Idempotent on `event_id`. Routes order vs offline sale via `payment_events` |
| POST | `/orders/{id}/dispute` | Body `{ "type": "not_collected\|customer_not_at_seat" }` |
| POST | `/customers/{id}/clear-dues` | Clears pending ledger via `PaymentProvider.CollectDues` |
| DELETE | `/customers/{id}` | Soft delete; blocked if dues remain. Audit rows kept (RBI retention TBD) |
| POST | `/vendors/{id}/offline-sale` | Body `{ "amount_paise": n }` — UPI only; `payment_verified` after webhook |

Policy numbers (timeouts, refund/penalty tiers, rolling windows, dues cap, 75/25 split) live in `internal/config/constants.go`.
