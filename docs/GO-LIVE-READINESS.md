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
npm run dev:e2e                           # terminal 1 — throwaway <db>_e2e, seeds the admin
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
- [x] ~~Tests share the dev database~~ — `npm test` drops + recreates `<db>_test`
      (jest `globalSetup` + `setupFiles`), and `npm run dev:e2e` does the same for
      `<db>_e2e` before serving the Flutter suite (`scripts/serve-e2e.ts`, also
      seeds the pilot admin). The dev / demo database is never touched by either.
- [ ] Console verification is a manual headless drive, not a committed script.

## Stage 2 — operational safety for a money pilot

- [x] **Audit log** (`audit_log`, migration 010) — every payment confirm, fund
      release, order transition (`order.create` / `payment_claim` / `ship` /
      `release`) and review-queue action (`kyc.review`, `user.flag`,
      `dispute.open` / `resolve`) is recorded with actor id + role, a summary and
      before/after metadata. `GET /api/admin/audit` (admin-only, filter by
      `action` / `target_id` / `actor_id`, paginate with `before`). Shown in the
      operator console's **Audit** tab. `tests/integration/audit-flow.test.ts`.
- [x] **Payouts + reconciliation** (`payouts` table, migration 011).
      `POST /api/payments/payout` (admin-only) records a traveller payout —
      amount / method / reference — for a `delivered` order, once, with an
      `order.payout` audit entry. `GET /api/ops/reconciliation` (admin-only)
      returns three buckets with running totals: **owed in** (pending_payment,
      goods + fee), **owed out** (delivered with no payout, goods only),
      **paid out** (recent payouts). New "Money" tab in the operator console
      shows all three and has the Record-payout button.
      `tests/integration/payout-flow.test.ts`.
- [x] **Rate limits + request-id.** `/api/payments/*` and `/api/offers/*/accept`
      capped at `MONEY_RATE_LIMIT_MAX` (30/min), `/api/uploads` at
      `UPLOAD_RATE_LIMIT_MAX` (20/min), `/api/auth/*` already at 20/min — all
      well under the global 200/min. Every response carries `x-request-id`
      (an inbound one from a proxy is honoured, else minted); Fastify logs it on
      every line in production. `tests/integration/rate-limit-flow.test.ts`.
- [ ] Structured logs in prod are on (`logger` when `NODE_ENV=production`) but
      unverified against a real log sink — revisit in Stage 3.

## Stage 2 status: complete.

## Stage 3 — deploy and re-verify

Host chosen: **Render** (API container, free) + **Neon** (Postgres, free).
Full steps in `docs/DEPLOY.md`.

- [x] Dockerfile (multi-stage) + `render.yaml` blueprint + idempotent
      migration-on-boot (`_migrations` tracking table) + HTTPS via Render.
- [x] Prod config: `NODE_ENV=production` turns on the strong-secret check, JSON
      logging, `trustProxy`, and managed-Postgres TLS. `render.yaml` wires
      `DATABASE_URL` / `JWT_SECRET` / `PUBLIC_BASE_URL` /
      `PILOT_PAYMENT_INSTRUCTIONS` / `MANUAL_MONEY_PILOT`.
- [ ] **You:** push to GitHub, create the Neon project, apply the Render
      blueprint, paste the two secrets, create the first admin (`docs/DEPLOY.md`).
- [ ] Move `uploads/` off local disk to **Cloudflare R2** (10 GB free) — on the
      free Render plan the disk is ephemeral, so images are lost on redeploy
      until this lands.
- [ ] Re-run both persona walk-throughs against the deployed URL.
- [ ] Uptime pinger on `/health` (free Render service sleeps after 15 min).
- [ ] Health-check alerting + error/log shipping.
