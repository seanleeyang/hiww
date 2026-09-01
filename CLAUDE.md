# Claude Code Review Hand-off for Hiww

This repository is a TypeScript + Fastify + PostgreSQL marketplace backend for a peer-to-peer cross-border shopping platform.

## Executive summary

Hiww is a modular monolith backend implementing the core marketplace flow for two key business models:

- Shopper-initiated flow: request -> offer -> accept -> pay -> deliver -> release
- Traveler-initiated flow: post trip -> pre-order -> pay -> ship -> release

The app is already functional and uses a real PostgreSQL database with Kysely migrations. The codebase includes auth, trips, requests, offers, orders, money, delivery/release logic, disputes, evidence, notifications, compliance/KYC, ops/admin workflows, and external provider abstraction.

## Current status

Completed and validated:

- Project scaffold and architecture
- PostgreSQL setup and migrations
- TypeScript build environment
- Auth flow implemented and tested
- Offer creation and acceptance tested
- Payment confirmation and ledger tested
- Delivery/release flow tested
- Dispute management tested
- Evidence upload/list tested
- Notifications flow tested
- Compliance/KYC flow tested
- Ops admin overview tested
- Admin review queue and action flow tested
- External provider abstraction implemented and validated
- CI/CD scaffolding and Docker deployment config added
- Postman demo collection provided for local API usage

Remaining operational work:

- Real payment provider integration (Opn or other vendor)
- Real identity/KYC provider integration (NDID or other vendor)
- Production secrets and deployment environment config
- Production monitoring / alerts / log shipping
- Rate limiting, audit logging, and security hardening

## Stack

- Node.js + TypeScript
- Fastify
- PostgreSQL
- Kysely ORM
- Zod validation
- Jest integration tests
- Decimal.js for money math

## Local development

Prerequisites:

- Node.js 18+
- PostgreSQL 14+
- npm

Install:

```bash
npm install
```

Environment:

```bash
cp .env.example .env
```

Then set values in `.env`, including a valid PostgreSQL URL and JWT secret:

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hiww
JWT_SECRET=your-secret
PORT=3000
NODE_ENV=development
```

Migrate and reset the database:

```bash
npx tsx reset-db.ts
npx tsx migrations/run.ts
```

Run the app:

```bash
npm run dev
```

Run tests:

```bash
npm test
```

Run a specific flow test:

```bash
npm test -- --runInBand tests/integration/admin-action-flow.test.ts
```

## Product architecture

Marketplace flows supported:

### Flow 1: Shopper-initiated
1. Shopper creates a request
2. Traveler creates an offer
3. Shopper accepts the offer
4. Payment is initiated and confirmed
5. Traveler purchases and ships goods
6. Funds are released after delivery confirmation

### Flow 2: Traveler-initiated
1. Traveler posts a trip
2. Shopper pre-orders items
3. Payment is made
4. Traveler buys while traveling
5. Traveler ships item
6. Funds are released after confirmation

## Key repository areas

- `src/main.ts` — Fastify bootstrap and route registration
- `src/db/connection.ts` — PostgreSQL connection setup
- `src/types/database.ts` — typed DB schema
- `src/utils/helpers.ts` — common utilities
- `src/utils/auth.ts` — token and password utilities
- `src/modules/auth/routes.ts` — register/login
- `src/modules/trips/routes.ts` — trip creation/listing
- `src/modules/requests/routes.ts` — request creation/listing
- `src/modules/offers/routes.ts` — offer and acceptance flows
- `src/modules/orders/routes.ts` — order creation and fee logic
- `src/modules/orders/delivery-routes.ts` — delivery and release logic
- `src/modules/disputes/routes.ts` — disputes
- `src/modules/evidence/routes.ts` — evidence management
- `src/modules/notifications/routes.ts` — notifications
- `src/modules/compliance/routes.ts` — KYC workflow
- `src/modules/ops/routes.ts` — operational overview
- `src/modules/admin/routes.ts` and `src/modules/admin/actions.ts` — review queue and actions
- `src/modules/money/routes.ts` — ledger and payment initiation
- `src/modules/external/routes.ts` — external provider hooks
- `src/services/providers/` — abstraction layer for payment and identity providers
- `migrations/` — database schema history
- `tests/integration/` — backend integration tests

## External provider abstraction

The provider layer is intentionally abstracted so the business logic is not coupled to a single vendor.

Files of interest:

- `src/services/providers/index.ts`
- `src/services/providers/types.ts`
- `src/services/providers/opn-payment-provider.ts`
- `src/services/providers/ndid-identity-provider.ts`

This supports switching between mock, Opn, NDID, or another provider without rewriting the core marketplace logic.

## Risks and assumptions to review

- Provider code is abstracted, but production SDK integrations still need real credentials and webhooks
- Current environment config is suitable for local dev but needs stronger separation for staging/production
- Core money movement logic is transactional, but production monitoring and reconciliation are still required
- The code is intentionally designed for a modular monolith; it is suitable for MVP and pilot deployment, not yet full multi-service scale

## Review tasks for Claude Code

Please review the repository with a production-minded lens and provide:

1. Architecture review: is the modular monolith structure sound for MVP and future scaling?
2. Security review: what are the most important missing security controls and production hardening tasks?
3. Data integrity review: any weak points in money, disputes, or order flows?
4. Provider abstraction review: is the abstraction clean and vendor-friendly?
5. Testing review: does the current test coverage match the critical commerce risk?
6. Deployment review: what should be configured next for staging and production?
7. Prioritization: what should happen next, in what order, and what is truly optional vs critical?

## Suggested next priorities

1. Choose real payment provider and configure credentials
2. Choose real identity/KYC provider and configure verification workflow
3. Add production environment separation and secret management
4. Add monitoring, alerting, and health checks for live deployment
5. Add payer/payout reconciliation and audit trails
6. Add rate limiting, security headers, and admin audit log review

## Important note

This is a working MVP backend intended for local use and pilot deployment. It is not yet a complete production financial stack without actual vendor integrations and operational hardening.

## Files to inspect for validation

- `README.md`
- `package.json`
- `src/main.ts`
- `src/config/env.ts`
- `src/services/providers/index.ts`
- `src/modules/money/routes.ts`
- `src/modules/orders/delivery-routes.ts`
- `src/modules/admin/actions.ts`
- `tests/integration/`
- `migrations/`

## Quick command check

This project was recently validated with:

```bash
npx tsx reset-db.ts ; npx tsx migrations/run.ts
npx tsx reset-db.ts ; npx tsx migrations/run.ts ; npm test -- --runInBand tests/integration/external-integrations-flow.test.ts
```

Those passed successfully in the local environment.
