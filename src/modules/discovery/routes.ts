import { FastifyInstance } from 'fastify';
import Decimal from 'decimal.js';
import { toUserSummary, USER_SUMMARY_COLUMNS, type UserSummary } from '@/utils/user-summary';

const PLATFORM_FEE_RATE = 0.08;
const EARN_ESTIMATE_CAP = 50000;

// A want and a trip are "on the same route" when the goods can be bought at
// either end of the trip.
function routeMatches(sourceCountry: string, trip: { departure_country: string; arrival_country: string }): boolean {
  return sourceCountry === trip.departure_country || sourceCountry === trip.arrival_country;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function summariesFor(request: any, ids: string[]): Promise<Map<string, UserSummary>> {
  const unique = [...new Set(ids)];
  if (unique.length === 0) return new Map();
  const rows = await request.db
    .selectFrom('users')
    .select([...USER_SUMMARY_COLUMNS])
    .where('id', 'in', unique)
    .execute();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return new Map(rows.map((r: any) => [r.id, toUserSummary(r)]));
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerDiscoveryRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { type?: string; category?: string; country?: string; limit?: string } }>(
    '/api/discover/feed',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const type = ['trips', 'wants'].includes(request.query.type) ? request.query.type : 'all';
      const category = (request.query.category || '').trim().toLowerCase();
      // Trips have no category of their own — a route (departure/arrival
      // country) is the dimension that actually applies to them.
      const country = (request.query.country || '').trim().toUpperCase();
      const limit = Math.min(50, Math.max(1, parseInt(request.query.limit || '30', 10) || 30));

      // Shared reference data (small at pilot scale — one query each).
      // Requests sent directly to one trip ("Request from this trip") are
      // excluded — they aren't a general match for other trips to surface.
      const openRequests = await request.db
        .selectFrom('requests')
        .select(['id', 'shopper_id', 'source_country', 'budget', 'category'])
        .where('status', '=', 'open')
        .where('target_trip_id', 'is', null)
        .execute();
      const publishedTrips = await request.db
        .selectFrom('trips')
        .select(['id', 'traveler_id', 'departure_country', 'arrival_country'])
        .where('status', '=', 'published')
        .where('return_date', '>=', new Date())
        .execute();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const items: any[] = [];

      if (type !== 'wants') {
        let tripsQuery = request.db
          .selectFrom('trips')
          .selectAll()
          .where('status', '=', 'published')
          .where('traveler_id', '!=', request.userId)
          .where('return_date', '>=', new Date());
        if (country) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          tripsQuery = tripsQuery.where((eb: any) =>
            eb.or([eb('departure_country', '=', country), eb('arrival_country', '=', country)])
          );
        }
        const trips = await tripsQuery.orderBy('created_at', 'desc').limit(limit).execute();
        const summaries = await summariesFor(request, trips.map((t: any) => t.traveler_id));

        for (const trip of trips) {
          const matched = openRequests.filter(
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (r: any) => r.shopper_id !== trip.traveler_id && routeMatches(r.source_country, trip)
          );
          // Per-item commission range (what carrying any one matched want
          // would pay), not a sum — a trip can't fulfil every match at once,
          // so a total overstates what's actually achievable.
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const commissions = matched.map((r: any) =>
            Decimal.min(new Decimal(r.budget).mul(PLATFORM_FEE_RATE), new Decimal(EARN_ESTIMATE_CAP)).toDecimalPlaces(2)
          );
          const earnMin = commissions.length ? commissions.reduce((a: Decimal, b: Decimal) => (b.lt(a) ? b : a)) : null;
          const earnMax = commissions.length ? commissions.reduce((a: Decimal, b: Decimal) => (b.gt(a) ? b : a)) : null;
          items.push({
            kind: 'trip',
            id: trip.id,
            created_at: trip.created_at,
            trip,
            traveler: summaries.get(trip.traveler_id) ?? null,
            match_count: matched.length,
            earn_min: earnMin && earnMin.gt(0) ? earnMin.toString() : null,
            earn_max: earnMax && earnMax.gt(0) ? earnMax.toString() : null,
          });
        }
      }

      if (type !== 'trips') {
        let q = request.db
          .selectFrom('requests')
          .selectAll()
          .where('status', '=', 'open')
          .where('shopper_id', '!=', request.userId)
          .where('target_trip_id', 'is', null)
          .orderBy('created_at', 'desc')
          .limit(limit);
        if (category) q = q.where('category', '=', category);
        const wants = await q.execute();
        const summaries = await summariesFor(request, wants.map((w: any) => w.shopper_id));

        for (const want of wants) {
          const matchCount = publishedTrips.filter(
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (t: any) => t.traveler_id !== want.shopper_id && routeMatches(want.source_country, t)
          ).length;
          items.push({
            kind: 'want',
            id: want.id,
            created_at: want.created_at,
            request: want,
            shopper: summaries.get(want.shopper_id) ?? null,
            match_count: matchCount,
          });
        }
      }

      items.sort(
        (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );

      reply.send({ success: true, data: { items: items.slice(0, limit) }, code: 'DISCOVER_FEED' });
    }
  );

  // "3 travelers fly Tokyo → Bangkok this month" — used by the Post Want screen.
  app.get<{ Querystring: { source_country?: string; source_city?: string } }>(
    '/api/discover/route-match',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const country = (request.query.source_country || '').trim();
      if (!country) {
        reply.send({ success: true, data: { count: 0, sample: [] }, code: 'ROUTE_MATCH' });
        return;
      }

      const trips = await request.db
        .selectFrom('trips')
        .innerJoin('users', 'users.id', 'trips.traveler_id')
        .select([
          'trips.id',
          'trips.departure_country',
          'trips.arrival_country',
          'trips.departure_city',
          'trips.arrival_city',
          'trips.departure_date',
          'trips.return_date',
          'users.full_name as traveler_name',
          'users.avatar_url as traveler_avatar_url',
        ])
        .where('trips.status', '=', 'published')
        .where('trips.traveler_id', '!=', request.userId)
        .where('trips.return_date', '>=', new Date())
        .where((eb: any) =>
          eb.or([
            eb('trips.arrival_country', '=', country),
            eb('trips.departure_country', '=', country),
          ])
        )
        .orderBy('trips.departure_date', 'asc')
        .execute();

      reply.send({
        success: true,
        data: { count: trips.length, sample: trips.slice(0, 5) },
        code: 'ROUTE_MATCH',
      });
    }
  );
}
