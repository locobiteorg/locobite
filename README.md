# LocoBite

LocoBite is a train-travel food ordering and delivery platform built as a Flutter mobile app with a Go backend and Supabase-powered discovery/auth. The app is designed for passengers who want to discover food vendors near their route, place orders before/while a train is approaching a station, track the order status, pay for it, and resolve account/dues situations without leaving the app.

This repository contains both the customer-facing mobile app and the backend service that handles stateful and money-sensitive workflows such as order placement, vendor acceptance/rejection, payment verification, disputes, and due tracking.

## What this project does

At a high level, LocoBite gives a passenger:

- a live-style train and station context view based on likely route stops
- a vendor discovery list for the selected upcoming station
- a menu browsing and cart experience with station-specific ordering
- a customer login flow using email OTP through Supabase
- order placement against a backend service that manages status transitions and state rules
- payment collection through QR or cash confirmation, simulated through the backend and webhook flow
- order status polling and customer actions such as cancellation, delay handling, and disputes
- account features including dues balance, account deletion, and purchase history

The key idea is that the app is not just a catalog. It is a transaction system built around train travel, where food delivery is time-sensitive and tied to station arrival, route direction, coach/seat, and payment verification.

## System architecture

The repository is split into three coordinated layers:

1. Flutter frontend
   - lives in `lib/`
   - handles onboarding, search, station selection, cart, checkout, payment, order tracking, and profile/account management
   - uses a repository abstraction so discovery logic can be swapped between mock and real data sources

2. Go backend
   - lives in `backend/`
   - owns orders, payments, disputes, dues, account operations, and other stateful money-touching logic
   - contains migrations, seed scripts, and server entrypoints for the actual business rules

3. Supabase + PostgreSQL
   - used for identity and read-only discovery data such as vendor/menu discovery and route/station context
   - stores auth and any data that do not require custom state-machine logic in the Go service
   - the backend note in this repo explicitly says read-only discovery stays on Supabase while stateful operations live in Go

## Core app flow

The user journey in the app is roughly:

1. App starts with a splash screen.
2. User reaches the login screen.
3. They enter a name and email, request an OTP, and verify it with Supabase email OTP.
4. After authenticated, the app calls the backend customer login API and stores the current customer in memory.
5. The home screen loads station and vendor discovery information and lets the user select the nearest upcoming station.
6. The user browses vendors and menus, adds items to cart, and verifies delivery details such as train number, coach, seat, and arrival time.
7. Cart submission triggers an order creation request to the backend.
8. The backend validates the menu selection and creates an order with status such as `requested` and related metadata.
9. The customer sees an order status screen that polls the backend every few seconds for updates.
10. Vendors can accept or reject the order, and lifecycle events advance through preparing, ready, out-for-delivery, and delivered.
11. Payment can take one of the supported flows: QR payment collection, cash confirmation, or a simulated webhook confirming a UPI payment.
12. Account screens support due clearance, order history review, saved route context, notifications controls, sign-out, and account deletion with audit retention.

## Frontend structure

The Flutter app is organized as a compact mobile app with these main concerns:

### Entry and app bootstrap
- `lib/main.dart`
  - initializes Flutter services
  - locks orientation to portrait
  - initializes Supabase with the provided project URL and anon key
  - runs the app with `LocoBiteApp`
  - chooses the discovery repository implementation used by the app

Currently the app is configured to use a mock discovery repository and is designed so that a real repository can be swapped without rewriting screens.

### Repository abstraction
- `lib/repositories/discovery_repository.dart`
  - defines the `DiscoveryRepository` interface
  - exposes methods for current train data, upcoming stations, and station vendors

- `lib/repositories/mock_discovery_repository.dart`
  - contains a demo route and station catalog with vendor and menu data
  - default sample route is a Konkan / coastal Karnataka train context with station names such as Udupi, Padubidri, Surathkal, Mangalore, and Gokarna Road
  - the mock catalog is intentionally rich enough to make the app feel like a working product even before a production backend is live

### Models
- `lib/shared/models/models.dart`
  - contains domain model classes for `TrainInfo`, `Station`, `MenuItem`, `Vendor`, `CartItem`, and `Customer`
  - includes JSON parsing for the customer model

- `lib/shared/models/order.dart`
  - defines `Order` and `OrderItem`
  - tracks order lifecycle fields such as `status`, `pickupStatus`, `amountPaise`, `paymentVerified`, `delayUpdatedAt`, `rejectionReason`, and item-level details

### API layer
- `lib/services/api_service.dart`
  - central HTTP client for every backend interaction
  - contains static endpoints for customer login, account refresh, clearing dues, placing orders, fetching order history, advancing order state, delay handling, payment collection, disputes, and webhook simulation
  - holds in-memory session state such as `currentCustomer` and `currentOrder`
  - includes static UUID mappings from local app IDs to backend UUIDs for vendors and menu items

This service is the bridge between Flutter screens and the backend API. If a backend call fails, it parses the API error payload and throws an exception with the backend message and code.

### Screen flow

- `lib/screens/splash_screen.dart`
  - branded splash animation
  - transitions into the login screen after ~2.2 seconds

- `lib/screens/login_screen.dart`
  - name + email entry
  - sends an OTP via `Supabase.instance.client.auth.signInWithOtp(email: ...)`
  - verifies OTP with `verifyOTP(...)`
  - logs the user into the backend customer system via `ApiService.login(...)`
  - navigates to home once login succeeds

- `lib/screens/home_screen.dart`
  - main discovery/home screen
  - lets the user select station and train details
  - filters vendors by station, veg-only preference, and search text
  - supports inline name prompts if the user is effectively a guest
  - holds a local cart list in memory while browsing vendors
  - routes to vendor detail views and cart views
  - includes grouped header, station picker, train bar, and vendor lists

- `lib/screens/vendor_screen.dart`
  - shows vendor banner, rating, trusted/FSSAI/zero-commission badges, and menu
  - allows item quantity adjustments and adds items to the cart
  - keeps cart state synchronized via `onCartChanged`

- `lib/screens/cart_screen.dart`
  - summarizes cart items and delivery details
  - calculates subtotal and convenience charges
  - checks whether the customer is blocked for dues before allowing checkout
  - builds the payload for the backend order creation call
  - converts arrival time to ISO UTC for backend scheduling
  - places the order and navigates the customer to the order status screen

- `lib/screens/order_status_screen.dart`
  - displays the order status through a progress flow
  - polls order status every 2 seconds using the customer order history endpoint
  - supports order cancellation when still within allowable rules
  - exposes simulation actions for: accept, reject, advance states, delay chips, and dispute filing
  - defines cancellation logic using order age, item restrictions, duplicate delay updates, and whether the item is a 10-minute item

- `lib/screens/payment_screen.dart`
  - generates a QR payload from the backend
  - allows confirmation of cash payment or simulation of a verified UPI webhook payment
  - handles the visual success state after payment is confirmed

- `lib/screens/profile_screen.dart`
  - displays customer profile information and dues amount
  - loads recent order history via `ApiService.getOrders(...)`
  - allows dues clearing
  - supports sign-out and account deletion
  - includes notification toggles and navigation to other account actions

- `lib/screens/rating_screen.dart`
  - review/feedback style screen attached to the transaction experience

## Order lifecycle and business rules in the app

The customer-facing app demonstrates a real order lifecycle, not just a shopping cart. The backend and UI work together around the following flow:

- Order is created after the cart is confirmed.
- Order status starts as `requested` and can be advanced by the vendor or simulated in the client.
- A vendor may `accept` or `reject` the order.
- Valid statuses include: `requested`, `accepted`, `preparing`, `ready`, `out_for_delivery`, and `delivered`.
- Delay chips can be applied with values like `+15`, `+30`, or `on-time`.
- Some orders cannot be cancelled if they contain 10-minute items, if the order is too old, or if delay was already updated.
- Dues can block customers from placing new orders until they clear outstanding balances.
- Disputes can be filed for cases such as “not collected” or “customer not at seat”, with refund and waiver calculations.

This logic is implemented in the backend and is mirrored in the app’s simulation tools so that the UX can model the end-to-end flow without a full vendor dashboard.

## Backend structure

The backend folder is a Go service for operational, stateful, and payment-sensitive functions. It is intentionally separated from the public discovery catalog and the auth layer.

Relevant backend structure:

- `backend/README.md`
  - describes the backend service, environment variables, migration commands, run instructions, endpoint summary, and policy notes

- `backend/PRODUCTION_CHECKLIST.md`
  - tracks completed work, remaining setup, and production gaps such as webhook verification and real payment provider integration

- `backend/cmd/`
  - contains the service entrypoints for server and migrations

- `backend/internal/`
  - contains backend business logic, config, and domain implementation

- `backend/migrations/`
  - database migration scripts

- `backend/supabase_manual_setup.sql`
  - manual database setup instructions for Supabase-specific schema work

## Backend responsibilities

The Go backend is responsible for:

- order creation and validation
- vendor accept/reject handling
- order lifecycle transitions
- payment collection and QR generation
- webhook event processing
- disputes and refunds
- customer dues ledger and blocking
- account deletion with audit retention
- offline sale flows and payment verification logic

The backend README explicitly states:

- read-only discovery (`menu_items`, `train_routes`, `route_stations`) remains on Supabase Auth + RLS
- the Go service does not expose those discovery endpoints
- money-touching operations are handled here

## Backend environment variables

The backend expects these values (as described in `backend/README.md`):

- `DATABASE_URL`
  - Postgres connection string to Supabase or local Postgres

- `PAYMENT_PROVIDER_API_KEY`
  - API key for Razorpay Route / Cashfree; currently stubbed in this repo

- `WEBHOOK_SECRET`
  - used for `POST /webhooks/payment` verification; currently stubbed and not production-safe

- `ADDR`
  - optional listen address, defaulting to `:8080`

Example command pattern:

```bash
export DATABASE_URL='postgresql://user:pass@localhost:5432/locobite?sslmode=disable'
export PAYMENT_PROVIDER_API_KEY='dev'
export WEBHOOK_SECRET='dev-secret'
go run ./cmd/server
```

## Database and seed flow

From the `backend/` directory:

```bash
export DATABASE_URL='postgresql://user:pass@localhost:5432/locobite?sslmode=disable'
go run ./cmd/migrate up
go run ./cmd/seed
```

Rollback support exists through:

```bash
go run ./cmd/migrate down
```

## API behavior summary

The backend covers the following kinds of requests:

- `GET /health` for liveness
- `POST /orders` for creating an order
- `POST /orders/{id}/accept` for vendor acceptance
- `POST /orders/{id}/reject` with a reason like `out_of_stock`, `too_busy`, `closing_soon`, or `other`
- `POST /orders/{id}/cancel` for customer cancellation when rules allow it
- `POST /orders/{id}/preparing`
- `POST /orders/{id}/ready`
- `POST /orders/{id}/out-for-delivery`
- `POST /orders/{id}/delivered`
- `PATCH /orders/{id}/delay` with a delay chip like `+15`, `+30`, or `on-time`
- `GET /customers/{id}/orders?limit=&offset=` to retrieve customer order history
- `POST /orders/{id}/reorder` to create a pre-filled cart from prior line items
- `POST /orders/{id}/collect-payment` to issue a QR for payment
- `POST /orders/{id}/cash-received` for self-reported cash handling
- `POST /webhooks/payment` for provider confirmation events
- `POST /orders/{id}/dispute` for customer disputes
- `POST /customers/{id}/clear-dues` to clear outstanding dues
- `DELETE /customers/{id}` to soft-delete a customer account
- `POST /vendors/{id}/offline-sale` for offline sale events

The backend also has operational policies and constants for refund tiers, penalty logic, due caps, rolling windows, and the 75/25 split logic discussed in the configuration layer.

## Payment and dues model

LocoBite is designed around actual transaction rules, not just mock UI actions:

- customer dues are tracked in paise and displayed in rupees
- outstanding dues can block a customer from further ordering
- clear dues is available as a dedicated API action
- payment QR generation is tied to a backend order
- a webhook can mark a payment as verified
- cash receipt is treated as an unverified vendor action and can be used for fallback flow testing
- disputes can convert into refund actions and may trigger waived fines depending on policy and thresholds

This is one of the stronger parts of the product: the app explicitly reflects account health and transaction consequences instead of treating order placement as a purely cosmetic interaction.

## Supabase and authentication flow

The Flutter app starts with `Supabase.initialize(...)` in `lib/main.dart` using a project URL and anon key. The user then performs email OTP auth, and on successful verification the app logs the user into the backend customer service by phone/email. This gives the app two identity layers:

- Supabase for email-based auth and session management
- backend customer API for the business/customer record in the operational system

This split keeps the app safe for identity verification while handling operational customer state in the Go backend.

## Mock vs real data note

The frontend includes a `MockDiscoveryRepository` as the default implementation. That means the app can run with realistic preview data for train stations, vendors, and menus without a working backend or database. The code is intentionally structured so that a production repository can replace the mock later with minimal UI changes.

The app comments reflect this directly:

- the repository layer is a single point for swapping mock or real implementations
- screens depend on the abstraction, not on the concrete data source

## Local development workflow

### Flutter app

From the repository root:

```bash
flutter pub get
flutter run
```

This will launch the app in a connected emulator or device.

### Backend

From the `backend/` directory:

```bash
export DATABASE_URL='postgresql://user:pass@localhost:5432/locobite?sslmode=disable'
export PAYMENT_PROVIDER_API_KEY='dev'
export WEBHOOK_SECRET='dev-secret'
go run ./cmd/server
```

## Production readiness notes

The project already includes a production checklist that calls out major remaining risks before launching to real users:

- webhook signature verification is currently stubbed
- payment providers are stubbed rather than connected to real Razorpay/Cashfree infrastructure
- production hosting and secrets must be configured properly
- actual provider SDKs and secure keys must replace the placeholder simulation layer

The `backend/PRODUCTION_CHECKLIST.md` file should be treated as the authoritative production deployment checklist.

## Project files worth knowing

- `lib/main.dart` — app bootstrap and Supabase init
- `lib/services/api_service.dart` — backend client and customer/order logic bridge
- `lib/repositories/discovery_repository.dart` — discovery contract
- `lib/repositories/mock_discovery_repository.dart` — demo route and vendor catalog
- `lib/screens/home_screen.dart` — primary app landing experience
- `lib/screens/vendor_screen.dart` — catalog + cart interactions
- `lib/screens/cart_screen.dart` — order creation and checkout
- `lib/screens/order_status_screen.dart` — status tracking and lifecycle simulation
- `lib/screens/profile_screen.dart` — account and dues management
- `backend/README.md` — Go backend design and endpoints
- `backend/PRODUCTION_CHECKLIST.md` — launch readiness checklist

## Summary

LocoBite is a train-food ordering platform with a strong product story: passengers discover stations and vendors, order food as they approach station stops, monitor the full lifecycle of the order, pay, resolve disputes, and maintain account health. The repository combines a polished Flutter app, a strict Go backend for transactional logic, and a Supabase-backed auth/discovery layer, giving a realistic end-to-end system design that is ready to evolve from mock/demo mode into production deployment.

If you want to work on this project further, the most important onboarding files are:

- this README
- `backend/README.md`
- `backend/PRODUCTION_CHECKLIST.md`
- `lib/main.dart`
- `lib/services/api_service.dart`
