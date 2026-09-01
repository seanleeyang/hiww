# --- build stage -------------------------------------------------------------
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# --- runtime stage ----------------------------------------------------------
FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Compiled app to run, plus source/migrations so `npm run db:migrate` (tsx) works.
COPY --from=build /app/dist ./dist
COPY --from=build /app/src ./src
COPY --from=build /app/public ./public
COPY --from=build /app/migrations ./migrations
COPY --from=build /app/scripts ./scripts
COPY --from=build /app/reset-db.ts ./reset-db.ts
COPY --from=build /app/tsconfig.json ./tsconfig.json

# Run migrations before the app starts:  docker compose run --rm api npm run db:migrate
USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/main.js"]
