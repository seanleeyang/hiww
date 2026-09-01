# 🚀 Hiww Backend - Quick Start Guide

## Status: MVP Foundation Ready ✅

Your marketplace backend is now scaffolded with:
- **Fastify** API server framework
- **PostgreSQL** database with Kysely ORM
- **TypeScript** strict mode enabled
- **Jest** testing framework ready
- **ESLint** code quality checks
- Complete modular architecture

---

## Prerequisites

- **Node.js 18+** installed
- **PostgreSQL 14+** running locally or remotely
- **.env file** configured

---

## Setup (5 minutes)

### 1. Configure Environment
```bash
cp .env.example .env
# Edit .env and set:
# DATABASE_URL=postgresql://user:password@localhost:5432/hiww
```

### 2. Install Dependencies
```bash
npm install
```
*(Already done, but run this if you pull new code)*

### 3. Create Database
```bash
npm run db:migrate
```
This creates all 10 tables in your PostgreSQL database.

### 4. Start Development Server
```bash
npm run dev
```
Server will start on `http://localhost:3000`

---

## Testing the API

### Health Check
```bash
curl http://localhost:3000/health
```

### Create a Trip (Traveler Flow)
```bash
curl -X POST http://localhost:3000/api/trips \
  -H "Content-Type: application/json" \
  -H "x-user-id: traveler-123" \
  -d '{
    "departure_country": "US",
    "arrival_country": "UK",
    "departure_date": "2024-10-01T10:00:00Z",
    "return_date": "2024-10-15T10:00:00Z",
    "max_weight_kg": 20,
    "max_items": 5
  }'
```

### Create an Item Request (Shopper Flow)
```bash
curl -X POST http://localhost:3000/api/requests \
  -H "Content-Type: application/json" \
  -H "x-user-id: shopper-456" \
  -d '{
    "item_description": "Apple MacBook Pro 16-inch M3",
    "source_country": "US",
    "category": "Electronics",
    "estimated_weight_kg": 2.5,
    "budget": "2500.00"
  }'
```

### Create an Order
```bash
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -H "x-user-id: shopper-456" \
  -d '{
    "trip_id": "trip-uuid-here",
    "item_description": "MacBook Pro 16in",
    "quantity": 1,
    "unit_price": "2500.00"
  }'
```

### List Trips (with pagination)
```bash
curl "http://localhost:3000/api/trips?page=1&limit=10"
```

---

## Project Structure

```
src/
├── main.ts                    # Fastify server entry point
├── modules/
│   ├── trips/                 # Trip management (Flow 2)
│   ├── requests/              # Item requests (Flow 1)
│   ├── orders/                # Orders & transactions
│   ├── money/                 # Ledger & payments
│   ├── identity/              # Users (TODO)
│   ├── offers/                # Quotes (TODO)
│   ├── evidence/              # Photos/docs (TODO)
│   ├── disputes/              # Dispute resolution (TODO)
│   ├── compliance/            # KYC/AML (TODO)
│   ├── notifications/         # Email/SMS (TODO)
│   └── ops/                   # Admin ops (TODO)
├── db/
│   └── connection.ts          # Kysely database setup
├── types/
│   ├── database.ts            # Table schemas
│   └── schemas.ts             # Zod validation schemas
└── middleware/
    └── error-handler.ts       # Global error handling

migrations/
├── 001_init.ts                # Initial schema
└── run.ts                     # Migration runner

tests/
├── unit/                      # Unit tests
└── integration/               # Integration tests
```

---

## Available Commands

```bash
npm run dev          # Start dev server with hot reload
npm run build        # Compile TypeScript to dist/
npm start            # Run compiled server
npm run test         # Run Jest tests
npm run test:watch   # Watch mode for tests
npm run lint         # Check code quality
npm run lint:fix     # Auto-fix linting issues
npm run db:migrate   # Run database migrations
npm run db:seed      # Seed database (TODO)
```

---

## Two Marketplace Flows

### Flow 1: Shopper-Initiated (Direct Request)
```
Shopper Creates Request 
    ↓
Traveler Reviews & Creates Offer
    ↓
Shopper Accepts & Pays
    ↓
Traveler Buys & Ships
    ↓
Money Released to Traveler
```

### Flow 2: Traveler-Initiated (Pre-Order)
```
Traveler Posts Trip (with items they'll buy)
    ↓
Shoppers Browse & Pre-Order
    ↓
Shoppers Pay
    ↓
Traveler Buys All Items During Trip
    ↓
Traveler Ships to Shoppers
    ↓
Money Released to Traveler
```

---

## API Response Format

All responses follow this structure:

**Success (2xx):**
```json
{
  "success": true,
  "data": { /* response data */ },
  "code": "OPERATION_CODE"
}
```

**Error (4xx/5xx):**
```json
{
  "success": false,
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `users` | User accounts & profiles |
| `trips` | Traveler trip postings |
| `requests` | Shopper item requests |
| `offers` | Traveler quotes on requests |
| `orders` | Confirmed transactions |
| `ledger_entries` | Payment/credit history |
| `fees` | Platform & processing fees |
| `evidence` | Photos, receipts, documents |
| `disputes` | Dispute records |
| `notifications` | Email/SMS/push logs |

---

## Next Priority Actions (CTO Roadmap)

### Week 1: Foundation
- [x] Project structure & scaffolding
- [ ] PostgreSQL database connection tested
- [ ] Authentication (JWT middleware)
- [ ] Basic unit tests for routes

### Week 2: Core Flows
- [ ] Complete Offer creation & acceptance
- [ ] Order state machine (pending → confirmed → in_transit → delivered)
- [ ] Payment initiation & confirmation
- [ ] Ledger tracking (credits/debits)

### Week 3: Extended Features
- [ ] User KYC/verification
- [ ] Notification system
- [ ] Dispute handling
- [ ] Admin operations

### Week 4: Production Ready
- [ ] Integration tests
- [ ] Error scenarios & edge cases
- [ ] Rate limiting
- [ ] Logging & monitoring
- [ ] Deploy to staging

---

## Troubleshooting

### "Could not find database"
```
Error: connect ECONNREFUSED
```
**Solution:** Ensure PostgreSQL is running and `DATABASE_URL` is correct in `.env`

### "TypeScript compilation errors"
```bash
npm run lint:fix
npm run build
```

### "Port 3000 already in use"
```bash
# Use different port
PORT=3001 npm run dev
```

---

## Documentation Links

- [Fastify Docs](https://fastify.dev/)
- [Kysely Docs](https://kysely.dev/)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Zod Validation](https://zod.dev/)

---

## Support

Questions? Check:
1. Console logs (check terminal where `npm run dev` is running)
2. Database logs (PostgreSQL logs)
3. Network tab (browser DevTools) for API responses
4. README.md (project overview)

Happy building! 🚀
