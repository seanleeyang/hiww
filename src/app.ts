import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import Fastify, { FastifyInstance, FastifyReply } from 'fastify';
import { sql } from 'kysely';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import type { Kysely } from 'kysely';
import { config } from '@/config/env';
import { createDatabase } from '@/db/connection';
import type { Database } from '@/types/database';
import { registerErrorHandler } from '@/middleware/error-handler';
import { registerAuthGuard } from '@/middleware/auth-guard';
import { getHealthSummary } from '@/config/health';
import { resolveLocale } from '@/i18n/locale';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerTripsRoutes } from '@/modules/trips/routes';
import { registerRequestsRoutes } from '@/modules/requests/routes';
import { registerOffersRoutes } from '@/modules/offers/routes';
import { registerOrdersRoutes } from '@/modules/orders/routes';
import { registerDeliveryRoutes } from '@/modules/orders/delivery-routes';
import { registerDisputesRoutes } from '@/modules/disputes/routes';
import { registerEvidenceRoutes } from '@/modules/evidence/routes';
import { registerNotificationsRoutes } from '@/modules/notifications/routes';
import { registerDeviceRoutes } from '@/modules/devices/routes';
import { registerComplianceRoutes } from '@/modules/compliance/routes';
import { registerOpsRoutes } from '@/modules/ops/routes';
import { registerAdminRoutes } from '@/modules/admin/routes';
import { registerAdminActionRoutes } from '@/modules/admin/actions';
import { registerAdminDevToolsRoutes } from '@/modules/admin/dev-tools';
import { registerMoneyRoutes } from '@/modules/money/routes';
import { registerPricingRoutes } from '@/modules/pricing/routes';
import { registerExternalRoutes } from '@/modules/external/routes';
import { registerDiscoveryRoutes } from '@/modules/discovery/routes';
import { registerReviewsRoutes } from '@/modules/reviews/routes';
import { registerMessagesRoutes } from '@/modules/messages/routes';
import { registerUploadRoutes } from '@/modules/uploads/routes';

function loadStatic(file: string): string {
  // Resolved from the process working directory, which is the project root for
  // `npm run dev`, `node dist/main.js`, and the test runner alike.
  try {
    return readFileSync(join(process.cwd(), 'public', file), 'utf8');
  } catch {
    return `<!doctype html><meta charset="utf-8"><title>Hiww</title><p>${file} not found. The API is still running.</p>`;
  }
}
const APP_HTML = loadStatic('app.html');
// The admin console is a built React app (admin-web/) — its index.html is
// copied to public/admin/ at Docker build time (see Dockerfile). Loaded here
// only as the SPA-routing fallback; the actual JS/CSS bundle is served as
// static files by @fastify/static below.
const ADMIN_INDEX_HTML = loadStatic('admin/index.html');

export interface BuildAppOptions {
  /**
   * Inject an existing database connection (used by tests so they can own the
   * lifecycle). When omitted, the app creates and — on close — destroys its own.
   */
  db?: Kysely<Database>;
}

/**
 * Build the fully wired Fastify application: plugins, the auth guard, the health
 * check and every route module. `main.ts` and the integration tests both go
 * through here so the real authentication path is always exercised.
 */
export async function buildApp(options: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({
    logger: config.nodeEnv === 'production',
    // Correlate every log line and error with one id. Honour an upstream
    // `x-request-id` (from a proxy) when present, otherwise mint one.
    requestIdHeader: 'x-request-id',
    genReqId: () => randomUUID(),
    // In production the app runs behind a platform proxy (Render / a load
    // balancer). Trust it so `request.protocol` reflects `x-forwarded-proto`
    // (needed to build https upload URLs) and rate limiting keys on the real
    // client IP from `x-forwarded-for`.
    trustProxy: config.nodeEnv === 'production',
  });

  // Echo the request id back so clients and proxies can line up their logs.
  app.addHook('onSend', async (request, reply) => {
    void reply.header('x-request-id', request.id);
  });

  const db = options.db ?? createDatabase();
  const ownsDb = options.db === undefined;

  await app.register(cors, { origin: true });
  // CSP is disabled so the single-file user web app (public/app.html, with
  // its inline <script>) works. The admin console (admin-web/) is a real
  // built app with no inline scripts and could run under a real CSP —
  // revisit this once app.html is retired too.
  // CORP is relaxed to cross-origin so the web app (a different origin) can load
  // uploaded images from `/uploads/*`; CORS is already `origin: true`.
  await app.register(helmet, {
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  });
  await app.register(rateLimit, {
    global: true,
    max: config.rateLimitMax,
    timeWindow: config.rateLimitWindow,
  });
  await app.register(multipart, {
    limits: { fileSize: config.maxUploadBytes, files: 1 },
  });

  // Make the database available to every handler, then run the auth guard.
  // Order matters: the guard reads `request.db` when checking admin rights.
  app.addHook('preHandler', async (request) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (request as any).db = db;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (request as any).locale = resolveLocale(request.headers['accept-language'] as string | undefined);
  });

  await registerErrorHandler(app);
  await registerAuthGuard(app);

  app.get('/health', async (_request, reply) => {
    let databaseOk = true;
    try {
      await sql`select 1`.execute(db);
    } catch {
      databaseOk = false;
    }
    reply.status(databaseOk ? 200 : 503).send({
      status: databaseOk ? 'ok' : 'error',
      timestamp: new Date().toISOString(),
      database: databaseOk ? 'ok' : 'error',
      env: getHealthSummary(),
    });
  });

  // Static pages that talk to this API: the user app (single HTML file) and
  // the admin console (a built React app — real JS/CSS assets, served from
  // disk; client-side routes like /admin/orders/<id> fall back to its
  // index.html via the notFoundHandler below).
  const html = (body: string) => async (_request: unknown, reply: FastifyReply): Promise<void> => {
    void reply.type('text/html; charset=utf-8').send(body);
  };
  app.get('/', html(APP_HTML));
  app.get('/app', html(APP_HTML));
  await app.register(fastifyStatic, {
    root: join(process.cwd(), 'public', 'admin'),
    prefix: '/admin/',
    decorateReply: false,
  });
  app.setNotFoundHandler((request, reply) => {
    if (request.method === 'GET' && request.url.startsWith('/admin')) {
      void reply.type('text/html; charset=utf-8').send(ADMIN_INDEX_HTML);
      return;
    }
    void reply.status(404).send({ success: false, error: 'Not found', code: 'NOT_FOUND' });
  });

  await registerAuthRoutes(app);
  await registerTripsRoutes(app);
  await registerRequestsRoutes(app);
  await registerOffersRoutes(app);
  await registerOrdersRoutes(app);
  await registerDeliveryRoutes(app);
  await registerDisputesRoutes(app);
  await registerEvidenceRoutes(app);
  await registerNotificationsRoutes(app);
  await registerDeviceRoutes(app);
  await registerComplianceRoutes(app);
  await registerOpsRoutes(app);
  await registerAdminRoutes(app);
  await registerAdminActionRoutes(app);
  await registerAdminDevToolsRoutes(app);
  await registerMoneyRoutes(app);
  await registerPricingRoutes(app);
  await registerExternalRoutes(app);
  await registerDiscoveryRoutes(app);
  await registerReviewsRoutes(app);
  await registerMessagesRoutes(app);
  await registerUploadRoutes(app);

  if (ownsDb) {
    app.addHook('onClose', async () => {
      await db.destroy();
    });
  }

  return app;
}
