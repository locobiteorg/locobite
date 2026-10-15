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
	vendor4 := uuid.MustParse("44444444-4444-4444-4444-444444444444")
	vendor5 := uuid.MustParse("55555555-5555-5555-5555-555555555555")
	vendor6 := uuid.MustParse("66666666-6666-6666-6666-666666666666")
	vendor7 := uuid.MustParse("77777777-7777-7777-7777-777777777777")
	vendor8 := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	vendor9 := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
	vendor10 := uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc")
	vendor11 := uuid.MustParse("dddddddd-dddd-dddd-dddd-dddddddddddd")
	vendor12 := uuid.MustParse("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")
	vendor13 := uuid.MustParse("10101010-1010-1010-1010-101010101010")
	vendor14 := uuid.MustParse("14141414-1414-1414-1414-141414141414")
	vendor15 := uuid.MustParse("15151515-1515-1515-1515-151515151515")
	vendor16 := uuid.MustParse("16161616-1616-1616-1616-161616161616")

	vendors := []struct {
		id      uuid.UUID
		name    string
		station string
		tier    string
		fssai   string
		accept  string
	}{
		{vendor1, "Sri Krishna Bhavan", "UD", "level_3", "valid", "manual"},
		{vendor2, "Malpe Harbour Kitchen", "UD", "level_2", "valid", "manual"},
		{vendor3, "Car Street Snacks", "UD", "level_1", "valid", "manual"},
		{vendor4, "Padubidri Platform Tea", "PDD", "level_1", "valid", "manual"},
		{vendor5, "Ghee Roast House", "MAJN", "level_3", "valid", "manual"},
		{vendor6, "Hampankatta Buns & Ice Cream", "MAJN", "level_2", "valid", "manual"},
		{vendor7, "Kundapur Kori Rotti", "KUDA", "level_2", "valid", "manual"},
		{vendor8, "Surathkal NITK Snacks", "SL", "level_1", "valid", "manual"},
		{vendor9, "Gokarna Beach Shack", "GOK", "level_2", "valid", "manual"},
		{vendor10, "Barkur Temple Canteen", "BKJ", "level_1", "valid", "manual"},
		{vendor11, "Mulki River Catch", "MULK", "level_2", "valid", "manual"},
		{vendor12, "Byndoor Beach Meals", "BYNR", "level_2", "valid", "manual"},
		{vendor13, "Bhatkal Biryani House", "BTJL", "level_3", "valid", "manual"},
		{vendor14, "Murdeshwar Temple Kitchen", "MRDW", "level_2", "valid", "manual"},
		{vendor15, "Central Station Tiffin", "MAQ", "level_1", "valid", "manual"},
		{vendor16, "Kumta Kokum Cafe", "GOK", "level_1", "valid", "manual"},
	}

	for _, v := range vendors {
		_, err := tx.Exec(ctx, `
			INSERT INTO vendors (id, name, station_code, subscription_tier, fssai_status, is_active, accept_mode, is_demo)
			VALUES ($1, $2, $3, $4, $5, TRUE, $6, TRUE)
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
		{uuid.MustParse("11111111-1111-1111-1111-111111111001"), vendor1, "Masala Dosa", 7000, "veg", false, false},
		{uuid.MustParse("11111111-1111-1111-1111-111111111002"), vendor1, "Idli Vada Combo", 5500, "veg", true, true},
		{uuid.MustParse("11111111-1111-1111-1111-111111111003"), vendor1, "Filter Coffee", 2500, "veg", true, true},
		{uuid.MustParse("11111111-1111-1111-1111-111111111004"), vendor1, "Sambar Rice", 8000, "veg", false, false},

		{uuid.MustParse("22222222-2222-2222-2222-222222222005"), vendor2, "Bangda Fry + Neer Dosa", 18000, "non_veg", false, false},
		{uuid.MustParse("22222222-2222-2222-2222-222222222006"), vendor2, "Fish Curry Rice", 16000, "non_veg", false, false},
		{uuid.MustParse("22222222-2222-2222-2222-222222222007"), vendor2, "Anjal Tawa Fry", 26000, "non_veg", false, false},
		{uuid.MustParse("22222222-2222-2222-2222-222222222008"), vendor2, "Neer Dosa (3 pcs)", 5000, "veg", true, true},

		{uuid.MustParse("33333333-3333-3333-3333-333333333009"), vendor3, "Goli Baje (6 pcs)", 4000, "veg", true, true},
		{uuid.MustParse("33333333-3333-3333-3333-333333333010"), vendor3, "Mangalore Buns (2)", 4500, "veg", true, true},
		{uuid.MustParse("33333333-3333-3333-3333-333333333011"), vendor3, "Cutting Chai", 2000, "veg", true, true},

		{uuid.MustParse("44444444-4444-4444-4444-444444444012"), vendor4, "Ginger Tea", 2000, "veg", true, true},
		{uuid.MustParse("44444444-4444-4444-4444-444444444013"), vendor4, "Bonda (4 pcs)", 3500, "veg", true, true},
		{uuid.MustParse("44444444-4444-4444-4444-444444444014"), vendor4, "Banana Chips", 4000, "veg", true, true},

		{uuid.MustParse("55555555-5555-5555-5555-555555555015"), vendor5, "Chicken Ghee Roast", 26000, "non_veg", false, false},
		{uuid.MustParse("55555555-5555-5555-5555-555555555016"), vendor5, "Prawn Ghee Roast", 32000, "non_veg", false, false},
		{uuid.MustParse("55555555-5555-5555-5555-555555555017"), vendor5, "Neer Dosa (4 pcs)", 6000, "veg", true, true},

		{uuid.MustParse("66666666-6666-6666-6666-666666666018"), vendor6, "Gadbad Ice Cream", 12000, "veg", true, false},
		{uuid.MustParse("66666666-6666-6666-6666-666666666019"), vendor6, "Mangalore Buns", 5000, "veg", true, true},
		{uuid.MustParse("66666666-6666-6666-6666-666666666020"), vendor6, "Tender Coconut", 6000, "veg", true, true},

		{uuid.MustParse("77777777-7777-7777-7777-777777777021"), vendor7, "Kori Rotti Meal", 18000, "non_veg", false, false},
		{uuid.MustParse("77777777-7777-7777-7777-777777777022"), vendor7, "Kori Gassi + Rice", 16000, "non_veg", false, false},
		{uuid.MustParse("77777777-7777-7777-7777-777777777023"), vendor7, "Veg Saaru Rice", 9000, "veg", false, false},

		{uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa024"), vendor8, "Pundi (3 pcs)", 4000, "veg", true, true},
		{uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa025"), vendor8, "Goli Baje", 3500, "veg", true, true},
		{uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa026"), vendor8, "Filter Coffee", 3000, "veg", true, true},

		{uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb027"), vendor9, "Fish Thali", 20000, "non_veg", false, false},
		{uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb028"), vendor9, "Veg Konkani Thali", 14000, "veg", false, false},
		{uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb029"), vendor9, "Sol Kadhi", 5000, "veg", true, true},

		{uuid.MustParse("cccccccc-cccc-cccc-cccc-ccccccccc030"), vendor10, "Holige (2 pcs)", 5000, "veg", true, true},
		{uuid.MustParse("cccccccc-cccc-cccc-cccc-ccccccccc031"), vendor10, "Rice Bath", 7000, "veg", false, false},
		{uuid.MustParse("cccccccc-cccc-cccc-cccc-ccccccccc032"), vendor10, "Buttermilk", 2500, "veg", true, true},

		{uuid.MustParse("dddddddd-dddd-dddd-dddd-ddddddddd033"), vendor11, "Prawn Fry Rice", 18000, "non_veg", false, false},
		{uuid.MustParse("dddddddd-dddd-dddd-dddd-ddddddddd034"), vendor11, "Kane Rava Fry", 22000, "non_veg", false, false},
		{uuid.MustParse("dddddddd-dddd-dddd-dddd-ddddddddd035"), vendor11, "Coconut Rice", 8000, "veg", false, false},

		{uuid.MustParse("eeeeeeee-eeee-eeee-eeee-eeeeeeeee036"), vendor12, "Byndoor Fish Curry Meal", 17000, "non_veg", false, false},
		{uuid.MustParse("eeeeeeee-eeee-eeee-eeee-eeeeeeeee037"), vendor12, "Crab Sukka", 18000, "non_veg", false, false},
		{uuid.MustParse("eeeeeeee-eeee-eeee-eeee-eeeeeeeee038"), vendor12, "Veg Meals", 9000, "veg", false, false},

		{uuid.MustParse("10101010-1010-1010-1010-101010101039"), vendor13, "Bhatkali Chicken Biryani", 22000, "non_veg", false, false},
		{uuid.MustParse("10101010-1010-1010-1010-101010101040"), vendor13, "Mutton Biryani", 26000, "non_veg", false, false},
		{uuid.MustParse("10101010-1010-1010-1010-101010101041"), vendor13, "Egg Biryani", 14000, "non_veg", false, false},
		{uuid.MustParse("10101010-1010-1010-1010-101010101042"), vendor13, "Veg Dum Biryani", 12000, "veg", false, false},

		{uuid.MustParse("14141414-1414-1414-1414-141414141043"), vendor14, "Temple Meals", 9000, "veg", false, false},
		{uuid.MustParse("14141414-1414-1414-1414-141414141044"), vendor14, "Poha + Coffee", 5000, "veg", true, true},
		{uuid.MustParse("14141414-1414-1414-1414-141414141045"), vendor14, "Coconut Payasa", 4000, "veg", true, true},

		{uuid.MustParse("15151515-1515-1515-1515-151515151046"), vendor15, "Rava Idli (4 pcs)", 5500, "veg", true, true},
		{uuid.MustParse("15151515-1515-1515-1515-151515151047"), vendor15, "Buns + Chutney", 5000, "veg", true, true},
		{uuid.MustParse("15151515-1515-1515-1515-151515151048"), vendor15, "Kesari Bath", 4000, "veg", true, true},
		{uuid.MustParse("15151515-1515-1515-1515-151515151049"), vendor15, "Filter Coffee", 3000, "veg", true, true},

		{uuid.MustParse("16161616-1616-1616-1616-161616161050"), vendor16, "Kokum Sherbet", 4000, "veg", true, true},
		{uuid.MustParse("16161616-1616-1616-1616-161616161051"), vendor16, "Pathrado (4 pcs)", 8000, "veg", true, true},
		{uuid.MustParse("16161616-1616-1616-1616-161616161052"), vendor16, "Upkari Rice", 11000, "veg", false, false},
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
		INSERT INTO customers (id, phone, name, dues_balance_paise, is_blocked_for_dues, is_demo)
		VALUES ($1, '9876543210', 'Arjun Kumar', 4000, FALSE, TRUE)
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
		SELECT $1, 4000, 'Unpaid balance from past cancellation', 'pending'
		WHERE NOT EXISTS (SELECT 1 FROM customer_dues_ledger WHERE customer_id = $1 AND reason = 'Unpaid balance from past cancellation')
	`, demoCustomerID)
	if err != nil {
		log.Fatalf("insert ledger outstanding due: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("seeded %d matching vendors and %d menu items at %s\n", len(vendors), len(items), time.Now().Format(time.RFC3339))
}
