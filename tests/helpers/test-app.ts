import 'dotenv/config';
import { randomUUID } from 'crypto';
import type { FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';
import { buildApp } from '@/app';
import { createDatabase } from '@/db/connection';
import type { Database } from '@/types/database';

export interface TestContext {
  app: FastifyInstance;
  db: Kysely<Database>;
}

/**
 * Build the real application (same wiring as production) against a fresh
 * database connection the test owns. Call `closeTestApp` in afterEach.
 */
export async function makeTestApp(): Promise<TestContext> {
  const db = createDatabase();
  const app = await buildApp({ db });
  await app.ready();
  return { app, db };
}

export async function closeTestApp(ctx: TestContext): Promise<void> {
  await ctx.app.close();
  await ctx.db.destroy();
}

export interface TestUser {
  userId: string;
  email: string;
  token: string;
}

/**
 * Register a user through the real auth route and return a usable bearer token.
 * Pass `admin: true` to also flip the account to the admin role.
 */
export async function createUser(
  ctx: TestContext,
  opts: {
    user_type?: 'shopper' | 'traveler' | 'both';
    admin?: boolean;
    email?: string;
    phone?: string;
  } = {}
): Promise<TestUser> {
  const email = opts.email ?? `user-${randomUUID()}@example.com`;

  const res = await ctx.app.inject({
    method: 'POST',
    url: '/api/auth/register',
    payload: {
      email,
      full_name: 'Test User',
      user_type: opts.user_type ?? 'both',
      phone: opts.phone ?? '+1 555 0100',
      password: 'SecurePass123!',
    },
  });

  if (res.statusCode !== 201) {
    throw new Error(`createUser failed (${res.statusCode}): ${res.body}`);
  }

  const { userId, token } = res.json().data as { userId: string; token: string };

  // Registration leaves the account pending email+phone verification (see
  // src/services/otp/). Auto-verify here so the rest of the suite can focus
  // on its own flow rather than re-proving the OTP mechanics every time —
  // that gets its own coverage in otp-verification-flow.test.ts.
  await ctx.db
    .updateTable('users')
    .set({ email_verified_at: new Date(), phone_verified_at: new Date() })
    .where('id', '=', userId)
    .execute();

  if (opts.admin) {
    await ctx.db.updateTable('users').set({ role: 'admin' }).where('id', '=', userId).execute();
  }

  return { userId, email, token };
}

export function authHeader(user: TestUser): { authorization: string } {
  return { authorization: `Bearer ${user.token}` };
}

/**
 * Fill in the phone + address fields an offer/accept requires (see
 * `src/utils/profile-guard.ts`). Writes straight to the DB — tests that
 * specifically exercise the profile-completeness gate should go through
 * `PATCH /api/me` instead.
 */
export async function completeProfile(ctx: TestContext, user: TestUser): Promise<void> {
  await ctx.db
    .updateTable('users')
    .set({
      phone: '+1 555 0100',
      address_street: '1 Market St',
      address_city: 'Springfield',
      address_postal_code: '12345',
      address_country: 'US',
    })
    .where('id', '=', user.userId)
    .execute();
}
