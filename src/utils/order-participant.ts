import { AppError } from '@/utils/helpers';

/**
 * Loads an order and confirms the caller is one of its two participants
 * (shopper or traveler) — the same check messages/evidence/disputes each
 * used to repeat with slight variations. Throws NOT_FOUND if the order
 * doesn't exist, FORBIDDEN (with the caller-supplied message key, so each
 * route keeps its own wording) if the caller isn't a party to it.
 */
export async function requireOrderParticipant(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: any,
  userId: string | undefined,
  orderId: string,
  forbiddenKey: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
): Promise<any> {
  const order = await db.selectFrom('orders').selectAll().where('id', '=', orderId).executeTakeFirst();
  if (!order) {
    throw new AppError('NOT_FOUND', 404, 'common.orderNotFound');
  }
  if (order.shopper_id !== userId && order.traveler_id !== userId) {
    throw new AppError('FORBIDDEN', 403, forbiddenKey);
  }
  return order;
}
