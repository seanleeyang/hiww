# Hiww - Cross-Border Shopping Marketplace

Hiww is a peer-to-peer cross-border shopping marketplace backend built with TypeScript, Fastify, PostgreSQL, and Kysely.

> **Status (Sept 2026): manual-money pilot only.** The automatic payment engine
> is switched off on purpose. Real money is moved by an admin by hand while the
> software tracks order state. See **[docs/PILOT-RUNBOOK.md](docs/PILOT-RUNBOOK.md)**
> to operate it and **[docs/CHANGES-2026-09.md](docs/CHANGES-2026-09.md)** for what
> changed and what is still required before taking real payments automatically.
> The "What is working" list below predates that review and is optimistic.
>
> **Run the pilot by clicking:** double-click `start-hiww.bat` → console opens at
> `http://localhost:3000/admin`. Guide: [docs/CONSOLE.md](docs/CONSOLE.md).
> **Money handling:** [docs/MONEY-TRACKER.md](docs/MONEY-TRACKER.md) ·
> **Providers:** [docs/PROVIDER-OUTREACH.md](docs/PROVIDER-OUTREACH.md) ·
> **Raw API:** [docs/POSTMAN.md](docs/POSTMAN.md)

## What is working

The backend includes the core marketplace flow and operating layers:

- Auth and user registration/login
- Traveler trip creation
- Shopper item requests
- Traveler offers and shopper acceptance
- Orders and fee calculation
- Ledger and payment confirmation
- Delivery and release flow
- Disputes and evidence
- Notifications
- KYC/compliance review
- Operational overview
- Admin review queue and resolution actions
- External provider integration hooks for payment and identity verification

## Marketplace flows

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

## Tech stack

- Node.js + TypeScript
- Fastify
- PostgreSQL
- Kysely ORM
- Zod validation
- Jest integration tests
- Decimal.js for monetary math

## Project structure

```bash
src/
├── db/
├── middleware/
├── modules/
│   ├── admin/
│   ├── auth/
│   ├── compliance/
│   ├── disputes/
│   ├── evidence/
│   ├── external/
│   ├── money/
│   ├── notifications/
│   ├── offers/
│   ├── ops/
│   ├── orders/
│   ├── requests/
│   ├── trips/
│   └── ...
├── types/
├── utils/
├── main.ts
└── ...

migrations/

tests/integration/
```

## Local setup

### Prerequisites

- Node.js 18+
- PostgreSQL 14+
- npm

### Install

```bash
npm install
```

### Environment

```bash
cp .env.example .env
```

Then update `.env` with a valid PostgreSQL URL and JWT secret:

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hiww
JWT_SECRET=your-secret
PORT=3000
NODE_ENV=development
```

### Run database migrations

```bash
npx tsx reset-db.ts
npx tsx migrations/run.ts
```

### Start the API

```bash
npm run dev
```

The server runs at `http://localhost:3000`.

### Run tests

```bash
npm test
```

or a specific flow:

```bash
npm test -- --runInBand tests/integration/admin-action-flow.test.ts
```

## Docker

### Build and run with Docker Compose

```bash
docker compose up --build
```

This runs:
- the API on port 3000
- PostgreSQL on port 5432

## Production notes

This project is structured as a modular monolith and is ready for a first production deployment or real-world pilot. The next production hardening stage is:

- real payment provider integration
- real KYC / identity provider integration
- audit logs and admin actions
- deployment pipeline and environment config separation
- rate limiting and security hardening

## License

Proprietary - Hiww
