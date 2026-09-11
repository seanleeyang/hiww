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
| traveller: order → record purchase → Mark as shipped | traveller order actions, purchase proof |
| shopper → Open chat → send messages | order chat, leakage redaction |

Status: **8/8 green.**

### Backend officer — operator console + scripts

- `admin-web/e2e/console.spec.ts` (Playwright) drives the **real** admin console
  against a running backend: sign in → Developer tools creates an order → confirm
  its payment through the confirm dialog → the `payment.confirm` entry shows in
  the Audit log → the ID-checks queue renders. Run:

  ```bash
  npm run dev:e2e                 # terminal 1 — API + built console on :3000
  cd admin-web && npm run e2e     # (first time: npm run e2e:install)
  ```

- `scripts/pilot-smoke-test.ps1` (full API lifecycle + security checks + dispute)
  — **fixed and green** (was stale: `POST /api/offers` now needs `trip_id`, and
  `/accept` takes no body).
- Both e2e suites run in CI on every relevant push/PR (`.github/workflows/e2e.yml`).

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

- [x] ~~Chat / messaging flow has no integration coverage~~ — `app_flow_test.dart`
      now drives shopper→traveler order chat through the real composer, and
      asserts a phone number typed into a message is redacted to `[number
      hidden]` before it's stored.
- [x] ~~Tests share the dev database~~ — `npm test` drops + recreates `<db>_test`
      (jest `globalSetup` + `setupFiles`), and `npm run dev:e2e` does the same for
      `<db>_e2e` before serving the Flutter suite (`scripts/serve-e2e.ts`, also
      seeds the pilot admin). The dev / demo database is never touched by either.
- [x] ~~Console verification is a manual headless drive~~ — `admin-web/e2e/console.spec.ts`
      (Playwright) is committed and runs in CI; see the officer section above.

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
- [x] Pushed to GitHub, Neon project created, Render blueprint applied, secrets
      set, first admin created. **Live: https://hiww-api.onrender.com**
      (admin console at `/admin`).
- [x] `uploads/` moved off local disk to **Cloudflare R2** (bucket
      `hiww-uploads`, public dev subdomain, CORS policy applied) —
      `src/services/storage/` picks R2 over local disk once `UPLOADS_BACKEND=r2`
      and the 5 `R2_*` vars are set. Deployed and verified.
- [x] Both persona walk-throughs re-run against the deployed URL: app side at
      **https://hiww.pages.dev** (Cloudflare Pages) end to end, and
      `scripts/pilot-smoke-test.ps1` against the live API + Neon (full order
      lifecycle, security checks, idempotent payment confirm, dispute
      open+resolve — all passed).
- [x] Uptime pinger: UptimeRobot HTTP(s) monitor on `/health` every 5 min, email
      alert contact on down/up (see `docs/DEPLOY.md`, "Uptime monitoring &
      alerting"). `/health` is now DB-aware (`select 1`, 503 on failure), not
      just a liveness check.
- [ ] Structured logs go to stdout as JSON in production and are captured by
      Render's own log viewer, but there is no dedicated log-shipping sink
      (e.g. Datadog/Logtail) or error-rate alerting beyond the uptime pinger —
      acceptable at pilot scale, worth revisiting if volume grows.

**Stage 3 is complete** except the log-shipping/error-alerting item above,
which is a nice-to-have, not a pilot blocker.

## Since Stage 3: real vendor integrations and feature work

Real payment/identity providers were never swapped in (still mock/manual —
`MANUAL_MONEY_PILOT`); everything below shipped on top of the deployed stack
without changing that. See `[[go-live-readiness]]` memory for full detail —
highlights: real push notifications (Android + Web via Firebase, iOS
scaffolded but blocked on Apple Developer enrollment + a Mac), Google + LINE +
Facebook social sign-in (Apple still stubbed, needs a $99/yr Apple Developer
Program membership), required purchase/delivery photo proof at both ends of
the handoff, offer
negotiation (counter/decline, capped at 2 rounds), payment-timeout
auto-cancel, AI receipt check + AI chat moderation (Claude), phone/OTP
verification at registration, and a full bottom-nav/UX redesign (Home /
Orders / Trips / Inbox) now covered by Flutter + Playwright e2e suites running
in CI (`.github/workflows/e2e.yml`).
