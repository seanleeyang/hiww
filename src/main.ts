import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import { config } from '@/config/env';
import { createDatabase } from '@/db/connection';
import { registerErrorHandler } from '@/middleware/error-handler';
import { registerTripsRoutes } from '@/modules/trips/routes';
import { registerRequestsRoutes } from '@/modules/requests/routes';
import { registerOrdersRoutes } from '@/modules/orders/routes';
import { registerMoneyRoutes } from '@/modules/money/routes';
import { registerAuthRoutes } from '@/modules/auth/routes';
import { registerOffersRoutes } from '@/modules/offers/routes';
import { registerDeliveryRoutes } from '@/modules/orders/delivery-routes';
import { registerDisputesRoutes } from '@/modules/disputes/routes';
import { registerEvidenceRoutes } from '@/modules/evidence/routes';
import { registerNotificationsRoutes } from '@/modules/notifications/routes';
import { registerComplianceRoutes } from '@/modules/compliance/routes';
import { registerOpsRoutes } from '@/modules/ops/routes';
import { registerAdminRoutes } from '@/modules/admin/routes';
import { registerAdminActionRoutes } from '@/modules/admin/actions';
import { registerExternalRoutes } from '@/modules/external/routes';
import { getHealthSummary } from '@/config/health';
import { verifyToken } from '@/utils/auth';

const PORT = config.port;
const HOST = config.host;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function start(): Promise<void> {
  const app = Fastify({
    logger: config.nodeEnv === 'production',
  });

  // Register plugins
  await app.register(cors, { origin: true });
  await app.register(helmet);

  // Initialize database
  const db = createDatabase();

  // Add database to request and resolve auth identity from bearer token
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.addHook('preHandler', async (request: any): Promise<void> => {
    request.db = db;

    const authHeader = request.headers.authorization;
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      try {
        const payload = verifyToken(authHeader.slice(7));
        request.userId = payload.userId;
        return;
      } catch (_error) {
        request.userId = undefined;
      }
    }

    request.userId = request.headers['x-user-id'] as string;
  });

  // Register error handler
  await registerErrorHandler(app);

  // Health check
  app.get('/health', async (_request, reply) => {
    reply.send({
      status: 'ok',
      timestamp: new Date().toISOString(),
      env: getHealthSummary(),
    });
  });

  // Register routes
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

  // Start server
  try {
    await app.listen({ port: PORT, host: HOST });
    console.log(`✅ Server running at http://${HOST}:${PORT}`);
    console.log(`📊 Database: ${process.env.DATABASE_URL?.split('@')[1] || 'not configured'}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

start().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
