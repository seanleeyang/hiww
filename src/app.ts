import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import Fastify, { FastifyInstance, FastifyReply } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import type { Kysely } from 'kysely';
import { config } from '@/config/env';
import { createDatabase } from '@/db/connection';
import type { Database } from '@/types/database';
import { registerErrorHandler } from '@/middleware/error-handler';
import { registerAuthGuard } from '@/middleware/auth-guard';
import { getHealthSummary } from '@/config/health';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerTripsRoutes } from '@/modules/trips/routes';
import { registerRequestsRoutes } from '@/modules/requests/routes';
import { registerOffersRoutes } from '@/modules/offers/routes';
import { registerOrdersRoutes } from '@/modules/orders/routes';
import { registerDeliveryRoutes } from '@/modules/orders/delivery-routes';
import { registerDisputesRoutes } from '@/modules/disputes/routes';
import { registerEvidenceRoutes } from '@/modules/evidence/routes';
import { registerNotificationsRoutes } from '@/modules/notifications/routes';
import { registerComplianceRoutes } from '@/modules/compliance/routes';
import { registerOpsRoutes } from '@/modules/ops/routes';
import { registerAdminRoutes } from '@/modules/admin/routes';
import { registerAdminActionRoutes } from '@/modules/admin/actions';
import { registerMoneyRoutes } from '@/modules/money/routes';
import { registerExternalRoutes } from '@/modules/external/routes';

function loadStatic(file: string): string {
  // Resolved from the process working directory, which is the project root for
  // `npm run dev`, `node dist/main.js`, and the test runner alike.
  try {
    return readFileSync(join(process.cwd(), 'public', file), 'utf8');
  } catch {
    return `<!doctype html><meta charset="utf-8"><title>Hiww</title><p>${file} not found. The API is still running.</p>`;
  }
}
const CONSOLE_HTML = loadStatic('admin.html');
const APP_HTML = loadStatic('app.html');

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
  });

  const db = options.db ?? createDatabase();
  const ownsDb = options.db === undefined;

  await app.register(cors, { origin: true });
  // CSP is disabled so the single-file local console (public/admin.html) works.
  // The API serves only JSON; revisit this when there is a real hosted frontend.
  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(rateLimit, {
    global: true,
    max: config.rateLimitMax,
    timeWindow: config.rateLimitWindow,
  });

  // Make the database available to every handler, then run the auth guard.
  // Order matters: the guard reads `request.db` when checking admin rights.
  app.addHook('preHandler', async (request) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (request as any).db = db;
  });

  await registerErrorHandler(app);
  await registerAuthGuard(app);

  app.get('/health', async (_request, reply) => {
    reply.send({
      status: 'ok',
      timestamp: new Date().toISOString(),
      env: getHealthSummary(),
    });
  });

  // Static pages that talk to this API: the operator console and the user app.
  const html = (body: string) => async (_request: unknown, reply: FastifyReply): Promise<void> => {
    void reply.type('text/html; charset=utf-8').send(body);
  };
  app.get('/', html(APP_HTML));
  app.get('/app', html(APP_HTML));
  app.get('/admin', html(CONSOLE_HTML));

  await registerAuthRoutes(app);
  await registerTripsRoutes(app);
  await registerRequestsRoutes(app);
  await registerOffersRoutes(app);
  await registerOrdersRoutes(app);
  await registerDeliveryRoutes(app);
  await registerDisputesRoutes(app);
  await registerEvidenceRoutes(app);
  await registerNotificationsRoutes(app);
  await registerComplianceRoutes(app);
  await registerOpsRoutes(app);
  await registerAdminRoutes(app);
  await registerAdminActionRoutes(app);
  await registerMoneyRoutes(app);
  await registerExternalRoutes(app);

  if (ownsDb) {
    app.addHook('onClose', async () => {
      await db.destroy();
    });
  }

  return app;
}
