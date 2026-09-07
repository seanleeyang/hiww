import { FastifyInstance } from 'fastify';
import { AppError } from '@/utils/helpers';
import { recordAudit, actorFromRequest } from '@/services/audit';

export async function registerAdminRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/admin/reviews', async (request: any, reply: any) => {
    try {
      const openDisputes = await request.db
        .selectFrom('disputes')
        .selectAll()
        .where('status', 'in', ['open', 'in_review'])
        .orderBy('created_at', 'desc')
        .execute();

      const pendingKyc = await request.db
        .selectFrom('users')
        .select(['id', 'email', 'full_name', 'kyc_status', 'created_at'])
        .where('kyc_status', 'in', ['pending', 'rejected'])
        .orderBy('created_at', 'desc')
        .execute();

      // Orders whose receipt the AI check flagged and no operator has cleared yet.
      const flaggedReceipts = await request.db
        .selectFrom('orders')
        .select([
          'id',
          'item_description',
          'total_price',
          'status',
          'purchase_proof_url',
          'receipt_risk',
          'receipt_analysis',
          'purchased_at',
        ])
        .where('receipt_risk', 'in', ['medium', 'high'])
        .where('receipt_reviewed_at', 'is', null)
        .orderBy('purchased_at', 'desc')
        .execute();

      // Chat messages the leakage/moderation check flagged and no operator
      // has cleared yet.
      const flaggedMessages = await request.db
        .selectFrom('messages')
        .innerJoin('users as sender', 'sender.id', 'messages.sender_id')
        .select([
          'messages.id',
          'messages.order_id',
          'messages.sender_id',
          'messages.body',
          'messages.flag_risk',
          'messages.flag_reasons',
          'messages.flag_summary',
          'messages.hidden_at',
          'messages.created_at',
          'sender.full_name as sender_name',
        ])
        .where('messages.flag_risk', 'in', ['medium', 'high'])
        .where('messages.flag_reviewed_at', 'is', null)
        .orderBy('messages.created_at', 'desc')
        .execute();

      const queue = [
        ...openDisputes.map((dispute: any) => ({
          type: 'dispute',
          id: dispute.id,
          status: dispute.status,
          order_id: dispute.order_id,
          initiator_id: dispute.initiator_id,
          reason: dispute.reason,
          resolution: dispute.resolution ?? null,
          created_at: dispute.created_at,
        })),
        ...pendingKyc.map((user: any) => ({
          type: 'kyc',
          id: user.id,
          status: user.kyc_status,
          user_id: user.id,
          email: user.email,
          full_name: user.full_name,
          created_at: user.created_at,
        })),
        ...flaggedReceipts.map((order: any) => ({
          type: 'receipt',
          id: order.id,
          order_id: order.id,
          status: order.status,
          item_description: order.item_description,
          total_price: order.total_price,
          receipt_url: order.purchase_proof_url,
          risk: order.receipt_risk,
          flags: order.receipt_analysis?.flags ?? [],
          summary: order.receipt_analysis?.summary ?? null,
          created_at: order.purchased_at,
        })),
        ...flaggedMessages.map((msg: any) => ({
          type: 'message',
          id: msg.id,
          order_id: msg.order_id,
          sender_id: msg.sender_id,
          sender_name: msg.sender_name,
          body: msg.body,
          risk: msg.flag_risk,
          flags: msg.flag_reasons ?? [],
          summary: msg.flag_summary ?? null,
          hidden: Boolean(msg.hidden_at),
          created_at: msg.created_at,
        })),
      ].sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

      reply.send({
        success: true,
        data: {
          count: queue.length,
          queue,
        },
        code: 'ADMIN_REVIEWS',
      });
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('DB_ERROR', 500, 'Failed to load admin review queue');
    }
  });

  // Operator has looked at a flagged receipt — drop it from the review queue.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post<{ Params: { id: string } }>('/api/admin/orders/:id/clear-receipt-flag', async (request: any, reply: any) => {
    const order = await request.db
      .selectFrom('orders')
      .select(['id', 'receipt_risk'])
      .where('id', '=', request.params.id)
      .executeTakeFirst();
    if (!order) {
      throw new AppError('NOT_FOUND', 404, 'Order not found');
    }

    await request.db
      .updateTable('orders')
      .set({ receipt_reviewed_at: new Date(), updated_at: new Date() })
      .where('id', '=', order.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'order.receipt_flag_cleared',
      targetType: 'order',
      targetId: order.id,
      summary: `Operator cleared the receipt flag on order ${order.id}`,
      metadata: { risk: order.receipt_risk ?? null },
    });

    reply.send({ success: true, data: { order_id: order.id }, code: 'RECEIPT_FLAG_CLEARED' });
  });

  // Operator has looked at a flagged message — drop it from the review queue.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post<{ Params: { id: string } }>('/api/admin/messages/:id/clear-flag', async (request: any, reply: any) => {
    const message = await request.db
      .selectFrom('messages')
      .select(['id', 'flag_risk'])
      .where('id', '=', request.params.id)
      .executeTakeFirst();
    if (!message) {
      throw new AppError('NOT_FOUND', 404, 'Message not found');
    }

    // Clearing means "I looked at this, it's fine" — restores a message the
    // AI check had hidden, in addition to dropping it from the queue.
    await request.db
      .updateTable('messages')
      .set({ flag_reviewed_at: new Date(), hidden_at: null })
      .where('id', '=', message.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'message.flag_cleared',
      targetType: 'message',
      targetId: message.id,
      summary: `Operator cleared the flag on message ${message.id}`,
      metadata: { risk: message.flag_risk ?? null },
    });

    reply.send({ success: true, data: { message_id: message.id }, code: 'MESSAGE_FLAG_CLEARED' });
  });

  // All trips, most recent first — lets an operator find and remove a
  // problematic post regardless of its current status.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/admin/trips', async (request: any, reply: any) => {
    const trips = await request.db
      .selectFrom('trips')
      .innerJoin('users', 'users.id', 'trips.traveler_id')
      .select([
        'trips.id',
        'trips.traveler_id',
        'trips.departure_country',
        'trips.arrival_country',
        'trips.departure_city',
        'trips.arrival_city',
        'trips.title',
        'trips.status',
        'trips.departure_date',
        'trips.return_date',
        'trips.created_at',
        'users.email as traveler_email',
        'users.full_name as traveler_name',
      ])
      .orderBy('trips.created_at', 'desc')
      .limit(200)
      .execute();

    reply.send({ success: true, data: { trips }, code: 'ADMIN_TRIPS' });
  });

  // Operator removes a trip — same effect as the traveler cancelling their
  // own, but without the active-order guard: this is for taking down a
  // problem post, not a routine cancel, so an operator can act even if the
  // trip has orders in flight (those still resolve independently).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post<{ Params: { id: string }; Body: unknown }>('/api/admin/trips/:id/remove', async (request: any, reply: any) => {
    const trip = await request.db
      .selectFrom('trips')
      .select(['id', 'status'])
      .where('id', '=', request.params.id)
      .executeTakeFirst();
    if (!trip) {
      throw new AppError('NOT_FOUND', 404, 'Trip not found');
    }

    const reason = typeof (request.body as any)?.reason === 'string' ? (request.body as any).reason.trim() : '';

    await request.db
      .updateTable('trips')
      .set({ status: 'cancelled', updated_at: new Date() })
      .where('id', '=', trip.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'trip.remove_by_admin',
      targetType: 'trip',
      targetId: trip.id,
      summary: `Operator removed trip ${trip.id}`,
      metadata: { from_status: trip.status, reason: reason || null },
    });

    reply.send({ success: true, data: { id: trip.id, status: 'cancelled' }, code: 'TRIP_REMOVED_BY_ADMIN' });
  });

  // Bulk version of the above — cancels every trip that's still visible in
  // the app (published or in progress). Leaves completed and already-
  // cancelled trips untouched, since those aren't showing anywhere anyway
  // and this is meant to clear the live listings, not rewrite history.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post('/api/admin/trips/remove-all', async (request: any, reply: any) => {
    const now = new Date();
    const removed = await request.db
      .updateTable('trips')
      .set({ status: 'cancelled', updated_at: now })
      .where('status', 'in', ['published', 'in_progress'])
      .returning(['id'])
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'trip.remove_by_admin',
      targetType: 'trip',
      targetId: 'bulk',
      summary: `Operator cancelled all ${removed.length} live trip(s)`,
      metadata: { count: removed.length, ids: removed.map((r: { id: string }) => r.id) },
    });

    reply.send({ success: true, data: { removed: removed.length }, code: 'TRIPS_REMOVED_BY_ADMIN' });
  });

  // Same as above, for wants.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/admin/requests', async (request: any, reply: any) => {
    const requests = await request.db
      .selectFrom('requests')
      .innerJoin('users', 'users.id', 'requests.shopper_id')
      .select([
        'requests.id',
        'requests.shopper_id',
        'requests.item_description',
        'requests.title',
        'requests.source_country',
        'requests.source_city',
        'requests.category',
        'requests.budget',
        'requests.status',
        'requests.created_at',
        'users.email as shopper_email',
        'users.full_name as shopper_name',
      ])
      .orderBy('requests.created_at', 'desc')
      .limit(200)
      .execute();

    reply.send({ success: true, data: { requests }, code: 'ADMIN_REQUESTS' });
  });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post<{ Params: { id: string }; Body: unknown }>('/api/admin/requests/:id/remove', async (request: any, reply: any) => {
    const itemRequest = await request.db
      .selectFrom('requests')
      .select(['id', 'status'])
      .where('id', '=', request.params.id)
      .executeTakeFirst();
    if (!itemRequest) {
      throw new AppError('NOT_FOUND', 404, 'Request not found');
    }

    const reason = typeof (request.body as any)?.reason === 'string' ? (request.body as any).reason.trim() : '';

    await request.db
      .updateTable('requests')
      .set({ status: 'cancelled', updated_at: new Date() })
      .where('id', '=', itemRequest.id)
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'request.remove_by_admin',
      targetType: 'request',
      targetId: itemRequest.id,
      summary: `Operator removed want ${itemRequest.id}`,
      metadata: { from_status: itemRequest.status, reason: reason || null },
    });

    reply.send({
      success: true,
      data: { id: itemRequest.id, status: 'cancelled' },
      code: 'REQUEST_REMOVED_BY_ADMIN',
    });
  });

  // Bulk version — cancels every want still visible in the app (open or
  // accepted). Leaves completed and already-cancelled wants untouched.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post('/api/admin/requests/remove-all', async (request: any, reply: any) => {
    const now = new Date();
    const removed = await request.db
      .updateTable('requests')
      .set({ status: 'cancelled', updated_at: now })
      .where('status', 'in', ['open', 'accepted'])
      .returning(['id'])
      .execute();

    await recordAudit(request.db, actorFromRequest(request), {
      action: 'request.remove_by_admin',
      targetType: 'request',
      targetId: 'bulk',
      summary: `Operator cancelled all ${removed.length} live want(s)`,
      metadata: { count: removed.length, ids: removed.map((r: { id: string }) => r.id) },
    });

    reply.send({ success: true, data: { removed: removed.length }, code: 'REQUESTS_REMOVED_BY_ADMIN' });
  });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/admin/users', async (request: any, reply: any) => {
    const users = await request.db
      .selectFrom('users')
      .select(['id', 'email', 'full_name', 'user_type', 'role', 'kyc_status', 'risk_status', 'created_at'])
      .orderBy('created_at', 'desc')
      .limit(200)
      .execute();

    reply.send({ success: true, data: { users }, code: 'ADMIN_USERS' });
  });

  // Append-only audit trail. Filter by ?action=, ?target_type=, ?target_id=,
  // ?actor_id=; page with ?limit= (max 200) and ?before= (an ISO timestamp).
  app.get<{
    Querystring: {
      action?: string;
      target_type?: string;
      target_id?: string;
      actor_id?: string;
      limit?: string;
      before?: string;
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  }>('/api/admin/audit', async (request: any, reply: any) => {
    const q = request.query;
    const limit = Math.min(200, Math.max(1, parseInt(q.limit || '50', 10) || 50));

    let query = request.db.selectFrom('audit_log').selectAll();
    if (q.action) query = query.where('action', '=', q.action);
    if (q.target_type) query = query.where('target_type', '=', q.target_type);
    if (q.target_id) query = query.where('target_id', '=', q.target_id);
    if (q.actor_id) query = query.where('actor_id', '=', q.actor_id);
    if (q.before) {
      const ts = new Date(q.before);
      if (!Number.isNaN(ts.getTime())) query = query.where('created_at', '<', ts);
    }

    const items = await query.orderBy('created_at', 'desc').limit(limit).execute();

    reply.send({ success: true, data: { items, limit }, code: 'ADMIN_AUDIT' });
  });
}
