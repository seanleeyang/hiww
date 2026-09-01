import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';

async function countTable(request: any, tableName: string): Promise<number> {
  const result = await request.db
    .selectFrom(tableName)
    .select((db: any) => [db.fn.count('id').as('count')])
    .executeTakeFirst();

  return Number(result?.count ?? 0);
}

async function countByStatus(request: any, tableName: string, fieldName: string, status: string): Promise<number> {
  const result = await request.db
    .selectFrom(tableName)
    .select((db: any) => [db.fn.count('id').as('count')])
    .where(fieldName, '=', status)
    .executeTakeFirst();

  return Number(result?.count ?? 0);
}

async function countUsersByType(request: any, userType: 'shopper' | 'traveler' | 'both'): Promise<number> {
  const result = await request.db
    .selectFrom('users')
    .select((db: any) => [db.fn.count('id').as('count')])
    .where('user_type', '=', userType)
    .executeTakeFirst();

  return Number(result?.count ?? 0);
}

export async function registerOpsRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/ops/overview', async (request: any, reply: any) => {
    try {
      const [users, shoppers, travelers, trips, requests, orders, openRequests, publishedTrips, pendingOrders] = await Promise.all([
        countTable(request, 'users'),
        countUsersByType(request, 'shopper'),
        countUsersByType(request, 'traveler'),
        countTable(request, 'trips'),
        countTable(request, 'requests'),
        countTable(request, 'orders'),
        countByStatus(request, 'requests', 'status', 'open'),
        countByStatus(request, 'trips', 'status', 'published'),
        countByStatus(request, 'orders', 'status', 'pending_payment'),
      ]);

      reply.send({
        success: true,
        data: {
          users,
          shoppers,
          travelers,
          trips,
          requests,
          orders,
          open_requests: openRequests,
          published_trips: publishedTrips,
          pending_orders: pendingOrders,
        },
        code: 'OPS_OVERVIEW',
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('DB_ERROR', 500, 'Failed to load ops overview');
    }
  });
}
