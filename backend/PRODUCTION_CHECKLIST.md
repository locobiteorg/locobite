# LocoBite Production Readiness Checklist

This document tracks the current completion status, what remains to be configured, and what modifications are critical before deploying the LocoBite backend and frontend to a production environment.

---

## 1. What is Done (Completed & Verified)
*   **Database Schema:** Complete relational tables in Postgres/Supabase for customers, vendors, orders, payment events, disputes, and dues ledger.
*   **Database Migrations & Seeding:** Run and verified on live Supabase instance.
*   **State Machine Logic:** Go backend pure state machine with full unit tests.
*   **Auth Flow:** Flutter updated to use Supabase Email OTP auth and sync automatically with the Go customer schema on successful login.
*   **Ledger & Dues Rules:** Automatic deduction of outstanding fines on order checkout, plus automated user blocking if dues exceed limit constants.
*   **Soft Deletion:** Compliant deletion flow keeping the necessary audit trails.

---

## 2. What is Left to Do (Immediate Tasks)
*   **Supabase Client Initialization:** Replace the placeholders in `lib/main.dart` with your real Supabase `url` and `anonKey`.
*   **Mobile Endpoint Configuration:** Point `baseUrl` in `lib/services/api_service.dart` to your hosted backend URL (or ngrok URL for local testing).

---

## 3. Production Gaps (Critical Before Launch)

### ⚠️ Webhook Cryptographic Verification
*   **Current State:** Signature verification is currently stubbed in `payments.VerifyWebhookSignature`.
*   **Action Needed:** Implement cryptographic validation (e.g., HMAC-SHA256 signature check) using keys provided by Razorpay or Cashfree once accounts are activated.

### ⚠️ Real Payment Gateways
*   **Current State:** Dynamic QR codes and dues collections are simulated by `StubProvider` in the Go backend.
*   **Action Needed:** Implement the real Razorpay/Cashfree Payouts API/SDK within the `PaymentProvider` interface.

### ⚠️ SMS Provider Setup (If switching back from Email)
*   **Current State:** Using Supabase Email OTP for testing ease.
*   **Action Needed:** If reverting back to Phone SMS OTP, configure a provider (Twilio, MSG91, Plivo) inside the Supabase Console.

### ⚠️ Production Hosting
*   **Current State:** Backend runs locally on localhost.
*   **Action Needed:** Deploy the Go binary (using a Dockerfile or directly) to a container host (Render, Fly.io, AWS ECS) and securely supply production credentials (`DATABASE_URL`, `WEBHOOK_SECRET`) as system env variables.
