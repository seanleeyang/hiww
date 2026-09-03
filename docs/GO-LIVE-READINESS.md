# Go-live readiness

Tracking what has to be true before Hiww runs a real pilot — verified end to end
for **both** personas: the app user (shopper / traveller) and the backend officer
(the person who moves money and works the review queue).

## Stage 1 — prove both personas work through their real interfaces

The rule here: "the tests pass" is not "it works against a real server". The
mocked-repo Flutter tests and the `inject`-based backend suite were both green
while three action buttons in the app were silently 400ing (see findings).

### App user — Flutter app

`mobile/integration_test/app_flow_test.dart` drives the **real** app (go_router +
Dio over sockets) against a running backend. Run:

```bash
npm run db:setup && npm run dev          # terminal 1
cd mobile && flutter test -d flutter-tester integration_test/app_flow_test.dart
```

| Flow | Covers |
|---|---|
| register → Browse → post a want | auth, feed, want create |
| accept an offer → "I've sent the payment" | offer accept, order screen, claim-payment |
| in-transit order → Confirm & release → review | fund release (highest stakes), review |
| traveller: open a want → make an offer | trip picker, date picker, offer create |
| report a problem → admin queue | dispute create, `GET /api/admin/reviews` |
| new user submits KYC → admin queue | KYC submit |
| traveller: My Trips → order → Mark as shipped | traveller order actions |

Status: **7/7 green.**

### Backend officer — operator console + scripts

- `public/admin.html` was click-through verified headless end to end: log in →
  Test lab creates a full order chain → Orders tab confirms payment (handles the
  `confirm()` + `prompt()` dialogs) → ship → receive → delivered; Review queue
  resolves a dispute; Users tab approves KYC; `/api/ops/overview` renders.
  **Works.**
- `scripts/pilot-smoke-test.ps1` (full API lifecycle + security checks + dispute)
  — **fixed and green** (was stale: `POST /api/offers` now needs `trip_id`, and
  `/accept` takes no body).

### Findings fixed in Stage 1

1. **Bodyless POSTs 400 against a real server.** `ApiClient` always sends
   `Content-Type: application/json`; Fastify rejects an empty body with that
   header. Broke accept-offer, claim-payment and chat mark-read since D3–D5.
   Fix: `ApiClient.post/patch` send `{}` when body-less. (`fa462a2`)
2. Country-picker dropdowns overflowed their row by ~0.4 px at narrow widths —
   `isExpanded: true`. (`ef690cb`)
3. `scripts/pilot-smoke-test.ps1` was calling the pre-migration-006 offer/accept
   shape. Updated.

### Still open in Stage 1

- [ ] Chat / messaging flow has no integration coverage.
- [x] ~~Tests share the dev database~~ — `npm test` now drops + recreates
      `<db>_test` and migrates it (jest `globalSetup` + `setupFiles`); the dev /
      demo database is never touched.
- [ ] Console verification is a manual headless drive, not a committed script.

## Stage 2 — operational safety for a money pilot

- [x] **Audit log** (`audit_log`, migration 010) — every payment confirm, fund
      release, order transition (`order.create` / `payment_claim` / `ship` /
      `release`) and review-queue action (`kyc.review`, `user.flag`,
      `dispute.open` / `resolve`) is recorded with actor id + role, a summary and
      before/after metadata. `GET /api/admin/audit` (admin-only, filter by
      `action` / `target_id` / `actor_id`, paginate with `before`). Shown in the
      operator console's **Audit** tab. `tests/integration/audit-flow.test.ts`.
- [ ] **Reconciliation view** for the officer — orders awaiting payment confirm,
      orders awaiting payout (delivered but not yet paid out), running totals.
      Note: there is still **no endpoint to record a payout** — during the pilot
      the officer pays the traveller out of band with nothing tracking it. That
      gap needs closing here (an `order.payout` audit action is reserved for it).
- [ ] Rate limits on `/api/payments/*`, `/api/offers/*/accept`, `/api/uploads`,
      `/api/auth/*`; request-id on every log line; structured logs in prod.

## Stage 3 — deploy and re-verify

- [ ] Dockerfile + host (Fly.io / Render / Cloud Run) with HTTPS.
- [ ] Prod env separation: `DATABASE_URL`, `JWT_SECRET`, `PUBLIC_BASE_URL`,
      `PILOT_PAYMENT_INSTRUCTIONS`, `MANUAL_MONEY_PILOT`.
- [ ] Move `uploads/` off local disk to object storage.
- [ ] Re-run both persona walk-throughs against the deployed URL.
- [ ] Health-check alerting + error/log shipping.
