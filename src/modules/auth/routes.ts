import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { hashPassword, signToken } from '@/utils/auth';

const registerSchema = z.object({
  email: z.string().email(),
  full_name: z.string().min(2),
  user_type: z.enum(['shopper', 'traveler', 'both']),
  password: z.string().min(8),
});

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/auth/register', async (request: any, reply: any) => {
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

  app.post<{ Body: unknown }>('/api/auth/login', async (request: any, reply: any) => {
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

    if (!user || user.password_hash !== hashPassword(parsed.data.password)) {
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
}
