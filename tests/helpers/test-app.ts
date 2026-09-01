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
  opts: { user_type?: 'shopper' | 'traveler' | 'both'; admin?: boolean; email?: string } = {}
): Promise<TestUser> {
  const email = opts.email ?? `user-${randomUUID()}@example.com`;

  const res = await ctx.app.inject({
    method: 'POST',
    url: '/api/auth/register',
    payload: {
      email,
      full_name: 'Test User',
      user_type: opts.user_type ?? 'both',
      password: 'SecurePass123!',
    },
  });

  if (res.statusCode !== 201) {
    throw new Error(`createUser failed (${res.statusCode}): ${res.body}`);
  }

  const { userId, token } = res.json().data as { userId: string; token: string };

  if (opts.admin) {
    await ctx.db.updateTable('users').set({ role: 'admin' }).where('id', '=', userId).execute();
  }

  return { userId, email, token };
}

export function authHeader(user: TestUser): { authorization: string } {
  return { authorization: `Bearer ${user.token}` };
}
