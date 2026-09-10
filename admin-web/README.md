# Hiww Admin

The staff-facing admin console — a Vite + React + TypeScript app. Replaces the
old hand-written single-file `public/admin.html`.

## Local development

Run the backend (`npm run dev` from the repo root), then in this directory:

```bash
npm install
npm run dev
```

The dev server proxies `/api` to `http://localhost:3000` (see
`vite.config.ts`), so no separate CORS setup is needed locally.

## Build

```bash
npm run build
```

Output goes to `dist/`. In production this is built by `Dockerfile`'s
`admin-build` stage and copied into the backend image at `public/admin/`,
served under `/admin/*` by `@fastify/static` (see `src/app.ts`). To try a
production build locally against the real backend, copy `dist/` into
`../public/admin/` and hit `http://localhost:3000/admin`.

## Test

```bash
npm test
```

Vitest + React Testing Library.

## Stack

- Vite + React 19 + TypeScript
- React Router for client-side routing
- TanStack Query for all data fetching/mutation state
- Plain CSS (`src/index.css`) — no component library or CSS-in-JS

## Auth

Same bearer-token model as every other client: `POST /api/auth/login`, then
`GET /api/me` to confirm `role === 'admin'`. Non-admins see a "not an admin"
message with the `npm run make-admin <email>` promotion command.
