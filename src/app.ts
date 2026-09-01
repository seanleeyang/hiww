import Fastify, { FastifyInstance } from 'fastify';
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
  await app.register(helmet);
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
