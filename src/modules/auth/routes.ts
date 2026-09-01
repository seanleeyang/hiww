import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { hashPassword, signToken, verifyPassword } from '@/utils/auth';
import { config } from '@/config/env';

// Tighter abuse protection on the credential endpoints than the global default.
const authRouteConfig = {
  rateLimit: { max: config.authRateLimitMax, timeWindow: config.rateLimitWindow },
};

const registerSchema = z.object({
  email: z.string().email(),
  full_name: z.string().min(2),
  user_type: z.enum(['shopper', 'traveler', 'both']),
  password: z.string().min(8),
});

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/auth/register', { config: authRouteConfig }, async (request: any, reply: any) => {
    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid registration data');
    }

    const existingUser = await request.db
      .selectFrom('users')
      .select('id')
      .where('email', '=', parsed.data.email)
      .executeTakeFirst();

    if (existingUser) {
      throw new AppError('USER_EXISTS', 409, 'User already exists');
    }

    const userId = generateId();
    await request.db
      .insertInto('users')
      .values({
        id: userId,
        email: parsed.data.email,
        full_name: parsed.data.full_name,
        user_type: parsed.data.user_type,
        kyc_status: 'pending',
        password_hash: hashPassword(parsed.data.password),
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    const token = signToken({
      userId,
      email: parsed.data.email,
      exp: Date.now() + 1000 * 60 * 60 * 24 * 7,
    });

    reply.status(201).send({
      success: true,
      data: { userId, email: parsed.data.email, token },
      code: 'USER_REGISTERED',
    });
  });

  app.post<{ Body: unknown }>('/api/auth/login', { config: authRouteConfig }, async (request: any, reply: any) => {
    const loginSchema = z.object({
      email: z.string().email(),
      password: z.string().min(8),
    });

    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'Invalid login data');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', parsed.data.email)
      .executeTakeFirst();

    if (!user || !verifyPassword(parsed.data.password, user.password_hash)) {
      throw new AppError('AUTH_ERROR', 401, 'Invalid email or password');
    }

    const token = signToken({
      userId: user.id,
      email: user.email,
      exp: Date.now() + 1000 * 60 * 60 * 24 * 7,
    });

    reply.send({
      success: true,
      data: { userId: user.id, email: user.email, token },
      code: 'USER_LOGGED_IN',
    });
  });

  // The signed-in user's own profile — the front-end calls this on load.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/me', async (request: any, reply: any) => {
    const me = await request.db
      .selectFrom('users')
      .select(['id', 'email', 'full_name', 'user_type', 'role', 'kyc_status', 'risk_status', 'created_at'])
      .where('id', '=', request.userId)
      .executeTakeFirst();

    if (!me) {
      throw new AppError('NOT_FOUND', 404, 'User not found');
    }

    reply.send({
      success: true,
      data: {
        ...me,
        pilot: {
          manual_money: config.manualMoneyPilot,
          payment_instructions: config.paymentInstructions,
        },
      },
      code: 'ME',
    });
  });
}
