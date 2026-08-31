package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	ctx := context.Background()
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		log.Fatal("DATABASE_URL is required")
	}
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	tx, err := pool.Begin(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer tx.Rollback(ctx)

	// Deterministic UUIDs for Vendors (matching Flutter app)
	vendor1 := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	vendor2 := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	vendor3 := uuid.MustParse("33333333-3333-3333-3333-333333333333")

	vendors := []struct {
		id     uuid.UUID
		name   string
		station string
		tier   string
		fssai  string
		accept string
	}{
		{vendor1, "Saoji Kitchen", "NGP", "level_3", "valid", "manual"},
		{vendor2, "Nagpur Orange Bites", "NGP", "level_2", "valid", "manual"},
		{vendor3, "Punjab Da Dhaba", "NGP", "level_1", "valid", "manual"},
	}

	for _, v := range vendors {
		_, err := tx.Exec(ctx, `
			INSERT INTO vendors (id, name, station_code, subscription_tier, fssai_status, is_active, accept_mode)
			VALUES ($1, $2, $3, $4, $5, TRUE, $6)
			ON CONFLICT (id) DO UPDATE SET
				name = EXCLUDED.name,
				station_code = EXCLUDED.station_code,
				subscription_tier = EXCLUDED.subscription_tier,
				fssai_status = EXCLUDED.fssai_status,
				accept_mode = EXCLUDED.accept_mode
		`, v.id, v.name, v.station, v.tier, v.fssai, v.accept)
		if err != nil {
			log.Fatalf("insert vendor %s: %v", v.name, err)
		}
	}

	type item struct {
		id       uuid.UUID
		vendorID uuid.UUID
		name     string
		price    int
		diet     string
		otc      bool
		tenMin   bool
	}
	items := []item{
		// Saoji Kitchen (Vendor 1)
		{uuid.MustParse("11111111-1111-1111-1111-111111111001"), vendor1, "Saoji Chicken Curry + Rice", 18000, "non_veg", false, false},
		{uuid.MustParse("11111111-1111-1111-1111-111111111002"), vendor1, "Saoji Mutton", 24000, "non_veg", false, false},
		{uuid.MustParse("11111111-1111-1111-1111-111111111003"), vendor1, "Plain Rice", 6000, "veg", false, false},
		{uuid.MustParse("11111111-1111-1111-1111-111111111004"), vendor1, "Dal Fry", 8000, "veg", false, false},
		
		// Nagpur Orange Bites (Vendor 2)
		{uuid.MustParse("22222222-2222-2222-2222-222222222005"), vendor2, "Poha", 4000, "veg", true, true},
		{uuid.MustParse("22222222-2222-2222-2222-222222222006"), vendor2, "Vada Pav", 3000, "veg", true, true},
		{uuid.MustParse("22222222-2222-2222-2222-222222222007"), vendor2, "Fresh Orange Juice", 6000, "veg", true, true},
		{uuid.MustParse("22222222-2222-2222-2222-222222222008"), vendor2, "Samosa (2 pcs)", 4000, "veg", true, true},

		// Punjab Da Dhaba (Vendor 3)
		{uuid.MustParse("33333333-3333-3333-3333-333333333009"), vendor3, "Veg Thali", 15000, "veg", false, false},
		{uuid.MustParse("33333333-3333-3333-3333-333333333010"), vendor3, "Paneer Butter Masala + 2 Rotis", 18000, "veg", false, false},
		{uuid.MustParse("33333333-3333-3333-3333-333333333011"), vendor3, "Chicken Curry + Rice", 20000, "non_veg", false, false},
	}

	for _, it := range items {
		_, err := tx.Exec(ctx, `
			INSERT INTO menu_items (id, vendor_id, name, price_paise, diet_type, is_otc, is_ten_min)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (id) DO UPDATE SET
				vendor_id = EXCLUDED.vendor_id,
				name = EXCLUDED.name,
				price_paise = EXCLUDED.price_paise,
				diet_type = EXCLUDED.diet_type,
				is_otc = EXCLUDED.is_otc,
				is_ten_min = EXCLUDED.is_ten_min
		`, it.id, it.vendorID, it.name, it.price, it.diet, it.otc, it.tenMin)
		if err != nil {
			log.Fatalf("insert menu item %s: %v", it.name, err)
		}
	}

	// Insert some demo customers
	demoCustomerID := uuid.MustParse("99999999-9999-9999-9999-999999999999")
	_, err = tx.Exec(ctx, `
		INSERT INTO customers (id, phone, name, dues_balance_paise, is_blocked_for_dues)
		VALUES ($1, '9876543210', 'Arjun Kumar', 4000, FALSE)
		ON CONFLICT (id) DO UPDATE SET
			phone = EXCLUDED.phone,
			name = EXCLUDED.name,
			dues_balance_paise = EXCLUDED.dues_balance_paise
	`, demoCustomerID)
	if err != nil {
		log.Fatalf("insert demo customer: %v", err)
	}

	// Insert user's customer
	userCustomerID := uuid.MustParse("88888888-8888-8888-8888-888888888888")
	_, err = tx.Exec(ctx, `
		INSERT INTO customers (id, phone, name, dues_balance_paise, is_blocked_for_dues)
		VALUES ($1, '9831579016', 'Sourav S', 0, FALSE)
		ON CONFLICT (id) DO UPDATE SET
			phone = EXCLUDED.phone,
			name = EXCLUDED.name
	`, userCustomerID)
	if err != nil {
		log.Fatalf("insert user customer: %v", err)
	}

	// Add an outstanding due to ledger matching the 4000 paise fine
	_, err = tx.Exec(ctx, `
		INSERT INTO customer_dues_ledger (customer_id, amount_paise, reason, status)
		VALUES ($1, 4000, 'Unpaid balance from past cancellation', 'pending')
	`, demoCustomerID)
	if err != nil {
		log.Fatalf("insert ledger outstanding due: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("seeded %d matching vendors and %d menu items at %s\n", len(vendors), len(items), time.Now().Format(time.RFC3339))
}
