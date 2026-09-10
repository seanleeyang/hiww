# --- backend build stage -----------------------------------------------------
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# --- admin console build stage ------------------------------------------------
FROM node:20-alpine AS admin-build
WORKDIR /app/admin-web

COPY admin-web/package*.json ./
RUN npm ci

COPY admin-web/ .
RUN npm run build

# --- runtime stage ----------------------------------------------------------
FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# The server itself runs via tsx (see "start" in package.json) so that the
# `@/*` path aliases used throughout src/ resolve at runtime the same way
# they do in dev and in the migration runner below — a plain compiled
# `node dist/main.js` can't resolve them (tsc only type-checks path aliases,
# it doesn't rewrite them into real relative imports). The build stage above
# still runs `tsc` as a type-check gate; dist/ itself isn't needed here.
COPY --from=build /app/src ./src
COPY --from=build /app/public ./public
COPY --from=build /app/migrations ./migrations
COPY --from=build /app/scripts ./scripts
COPY --from=build /app/reset-db.ts ./reset-db.ts
COPY --from=build /app/tsconfig.json ./tsconfig.json

# The admin console (a real React/Vite app — see admin-web/) is built
# separately above and its static output copied in here, served under
# /admin/* by @fastify/static (see src/app.ts).
COPY --from=admin-build /app/admin-web/dist ./public/admin

# uploads/ is created at boot (registerUploadRoutes) and must be writable by
# the unprivileged `node` user this container drops to below; everything
# COPYed above is owned by root, so without this the mkdir fails EACCES.
# NB Render's free-tier disk is ephemeral — this dir (and anything in it)
# does not survive a redeploy; see docs/DEPLOY.md for the object-storage TODO.
RUN mkdir -p /app/uploads && chown -R node:node /app/uploads

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=25s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Apply any pending migrations, then start. `db:migrate` is idempotent — it
# tracks what has run in a `_migrations` table.
CMD ["sh", "-c", "npm run db:migrate && npm start"]
