import { FastifyInstance } from 'fastify';

interface InjectedUser {
  userId: string;
  token: string;
  email: string;
}

function fakePhone(): string {
  return `+1555${Math.floor(1_000_000 + Math.random() * 8_999_999)}`;
}

function assertOk(res: { statusCode: number; body: string }, step: string): void {
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Object.assign(new Error(`${step} failed (${res.statusCode}): ${res.body}`), { statusCode: 502 });
  }
}

/**
 * Dev-only: spins up two throwaway users and drives them through the real
 * HTTP routes (via Fastify's `inject`, same mechanism the integration test
 * suite uses) to produce one ready-to-use order for admin to exercise —
 * confirm payment, cancel it, open a dispute, etc. — without needing real
 * email/SMS delivery. OTP verification is bypassed with a direct DB update
 * immediately after registering each user, since there's no legitimate API
 * path around it; everything else (want, trip, offer, accept) goes through
 * the exact same validated routes a real user hits.
 */
export async function registerAdminDevToolsRoutes(app: FastifyInstance): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.post('/api/admin/dev/create-test-order', async (request, reply) => {
    const stamp = Date.now();

    async function registerUser(role: 'shopper' | 'traveler'): Promise<InjectedUser> {
      const email = `test-${role}-${stamp}@pilot.local`;
      const res = await request.server.inject({
        method: 'POST',
        url: '/api/auth/register',
        payload: {
          email,
          full_name: `Test ${role === 'shopper' ? 'Shopper' : 'Traveler'} ${stamp}`,
          user_type: role,
          phone: fakePhone(),
          password: 'SecurePass123!',
        },
      });
      assertOk(res, `register ${role}`);
      const { userId, token } = res.json().data as { userId: string; token: string };

      await request.db
        .updateTable('users')
        .set({ email_verified_at: new Date(), phone_verified_at: new Date(), kyc_status: 'approved' })
        .where('id', '=', userId)
        .execute();

      const profileRes = await request.server.inject({
        method: 'PATCH',
        url: '/api/me',
        headers: { authorization: `Bearer ${token}` },
        payload: {
          address_street: '1 Test Street',
          address_city: 'Bangkok',
          address_postal_code: '10110',
          address_country: 'TH',
        },
      });
      assertOk(profileRes, `complete ${role} profile`);

      return { userId, token, email };
    }

    const shopper = await registerUser('shopper');
    const traveler = await registerUser('traveler');

    const wantRes = await request.server.inject({
      method: 'POST',
      url: '/api/requests',
      headers: { authorization: `Bearer ${shopper.token}` },
      payload: {
        item_description: 'Console test item for QA / demos',
        source_country: 'JP',
        category: 'general',
        estimated_weight_kg: 1,
        budget: '90.00',
        destination_country: 'TH',
      },
    });
    assertOk(wantRes, 'create want');
    const requestId = wantRes.json().data.id as string;

    const tripRes = await request.server.inject({
      method: 'POST',
      url: '/api/trips',
      headers: { authorization: `Bearer ${traveler.token}` },
      payload: {
        departure_country: 'JP',
        arrival_country: 'TH',
        departure_date: new Date(Date.now() + 86_400_000).toISOString(),
        return_date: new Date(Date.now() + 10 * 86_400_000).toISOString(),
        max_weight_kg: 20,
        max_items: 5,
      },
    });
    assertOk(tripRes, 'create trip');
    const tripId = tripRes.json().data.id as string;

    const offerRes = await request.server.inject({
      method: 'POST',
      url: '/api/offers',
      headers: { authorization: `Bearer ${traveler.token}` },
      payload: {
        request_id: requestId,
        trip_id: tripId,
        quoted_price: '85.00',
        delivery_date: new Date(Date.now() + 8 * 86_400_000).toISOString(),
      },
    });
    assertOk(offerRes, 'make offer');
    const offerId = offerRes.json().data.id as string;

    const acceptRes = await request.server.inject({
      method: 'POST',
      url: `/api/offers/${offerId}/accept`,
      headers: { authorization: `Bearer ${shopper.token}` },
      payload: {},
    });
    assertOk(acceptRes, 'accept offer');
    const orderId = acceptRes.json().data.order_id as string;

    reply.status(201).send({
      success: true,
      data: { order_id: orderId, shopper_email: shopper.email, traveler_email: traveler.email },
      code: 'TEST_ORDER_CREATED',
    });
  });
}
