import { FastifyInstance } from 'fastify';
import { sql } from 'kysely';
import { AppError, generateId } from '@/utils/helpers';
import { reviewSchema } from '@/types/schemas';
import { toUserSummary, USER_SUMMARY_COLUMNS } from '@/utils/user-summary';

/**
 * Reviews are left on a completed (`delivered`) order by one participant about
 * the other. Aggregates live on `users.rating_sum` / `rating_count` so a feed of
 * cards can show "4.9" without a per-row join.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerReviewsRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Params: { id: string }; Body: unknown }>(
    '/api/orders/:id/review',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = reviewSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'Invalid review');
      }

      const order = await request.db
        .selectFrom('orders')
        .selectAll()
        .where('id', '=', request.params.id)
        .executeTakeFirst();

      if (!order) {
        throw new AppError('NOT_FOUND', 404, 'Order not found');
      }

      const isShopper = order.shopper_id === request.userId;
      const isTraveler = order.traveler_id === request.userId;
      if (!isShopper && !isTraveler) {
        throw new AppError('FORBIDDEN', 403, 'You are not part of this order');
      }
      if (order.status !== 'delivered') {
        throw new AppError('INVALID_STATUS', 409, 'You can review once the order is delivered');
      }

      const revieweeId = isShopper ? order.traveler_id : order.shopper_id;

      const existing = await request.db
        .selectFrom('reviews')
        .select('id')
        .where('order_id', '=', order.id)
        .where('reviewer_id', '=', request.userId)
        .executeTakeFirst();
      if (existing) {
        throw new AppError('ALREADY_REVIEWED', 409, 'You have already reviewed this order');
      }

      const reviewId = generateId();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await request.db.transaction().execute(async (trx: any) => {
        await trx
          .insertInto('reviews')
          .values({
            id: reviewId,
            order_id: order.id,
            reviewer_id: request.userId,
            reviewee_id: revieweeId,
            rating: parsed.data.rating,
            comment: parsed.data.comment ?? null,
            created_at: new Date(),
          })
          .execute();

        await trx
          .updateTable('users')
          .set({
            rating_sum: sql`rating_sum + ${parsed.data.rating}`,
            rating_count: sql`rating_count + 1`,
            updated_at: new Date(),
          })
          .where('id', '=', revieweeId)
          .execute();
      });

      reply.status(201).send({ success: true, data: { id: reviewId }, code: 'REVIEW_CREATED' });
    }
  );

  app.get<{ Params: { id: string } }>(
    '/api/users/:id/reviews',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const user = await request.db
        .selectFrom('users')
        .select([...USER_SUMMARY_COLUMNS])
        .where('id', '=', request.params.id)
        .executeTakeFirst();
      if (!user) {
        throw new AppError('NOT_FOUND', 404, 'User not found');
      }

      const items = await request.db
        .selectFrom('reviews')
        .innerJoin('users as reviewer', 'reviewer.id', 'reviews.reviewer_id')
        .select([
          'reviews.id',
          'reviews.rating',
          'reviews.comment',
          'reviews.created_at',
          'reviewer.full_name as reviewer_name',
          'reviewer.avatar_url as reviewer_avatar_url',
        ])
        .where('reviews.reviewee_id', '=', request.params.id)
        .orderBy('reviews.created_at', 'desc')
        .limit(50)
        .execute();

      reply.send({
        success: true,
        data: { user: toUserSummary(user), items },
        code: 'USER_REVIEWS',
      });
    }
  );
}
