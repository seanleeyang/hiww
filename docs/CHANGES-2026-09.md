# Security & pilot-readiness changes — September 2026

Context: the repo was received as a hand-off described as a "working MVP". A
review found it was a functional demo but **not safe for real users or money**.
These changes make it safe enough to run a **manual-money pilot** (see
`PILOT-RUNBOOK.md`). They do **not** make it a production financial system.

Git history: `git log --oneline`. Baseline commit = code as received.
Full backup zip: `Documents/Hiww-backup-20260901-171834.zip`.

---

## Phase 1 — "Shut the doors"  (commit: `Phase 1: shut the doors`)

| Problem found | Fix |
|---------------|-----|
| Any request could impersonate any user by sending an `x-user-id` header. | Removed. All non-public routes now require a valid login token. (`src/middleware/auth-guard.ts`) |
| No notion of staff/admin. Anyone could approve KYC, resolve disputes, read any ledger, flag users. | Added `users.role` (migration `004`). Admin-only routes gated centrally. `npm run make-admin <email>` promotes a user. |
| Payment could be "confirmed" with no money, and confirm + release **paid the traveler twice** and invented balances. | During the pilot these routes only move order status, idempotently, and write **no** ledger entries. Real money is handled by the admin out-of-band. (`MANUAL_MONEY_PILOT=true`) |
| Passwords hashed with unsalted SHA-256. | Now scrypt + per-user salt. (`src/utils/auth.ts`) |
| Hand-rolled token check crashed (500) on a malformed token; ignored expiry edge cases. | Fixed constant-time compare; expiry strictly enforced. |
| Weak default `JWT_SECRET`; a real secret committed in `docker-compose.yml`; DB password hard-coded in `reset-db.ts`. | App refuses to start without a strong `JWT_SECRET`. Secrets removed from compose and `reset-db.ts` (now read from env). |
| Tests re-implemented a fake auth layer, so the real wiring was never tested. Broken eslint config. | Extracted `src/app.ts` (`buildApp`) used by both `main.ts` and every test. eslint config fixed. CI now type-checks + lints. |

## Phase 2 — Abuse protection  (commit: `Phase 2: abuse protection`)

- Added `@fastify/rate-limit`: 200 req/min per IP globally, 20/min on
  `/api/auth/*`. Configurable via `RATE_LIMIT_*` env vars.
- Error handler now returns the right status (400 validation, 429 rate limit)
  instead of turning everything into a 500.

## Phase 3 — Pilot & deploy hygiene  (commit: `Phase 3: pilot runbook + deploy`)

- `docs/PILOT-RUNBOOK.md` — how to operate the manual-money pilot.
- Multi-stage `Dockerfile` (`npm ci`, non-root `node` user, `HEALTHCHECK`).
- `docker-compose.yml` takes secrets from the environment, DB port not published.
- Handy npm scripts: `db:setup`, `db:migrate`, `db:reset`, `make-admin`, `typecheck`.

Test status: **13 suites / 33 tests green**, including new negative tests
(no-token → 401, non-admin → 403, spoofed header ignored, idempotent
confirm/release, rate-limit trips).

---

## NOT done yet — required before taking real money automatically

1. Real payment provider (Opn/Wise/etc) + webhook signature verification.
2. Real identity/KYC provider integration.
3. Proper double-entry ledger with an escrow + platform account; funds held on
   payment, released on delivery/dispute; reconciliation against the provider.
4. Dispute resolution that actually moves money.
5. HTTPS + hardened hosting, secret manager, log shipping, error tracking,
   backups, staging environment.
6. Admin web UI (pilot is run via API calls).
7. Password reset / email verification.
8. Type the route handlers (currently `any`; eslint rule downgraded to warn).
9. `timestamptz` columns; DB CHECK constraints; audit log table.
10. Fix or delete the unused `request_id` branch in `POST /api/orders`.
