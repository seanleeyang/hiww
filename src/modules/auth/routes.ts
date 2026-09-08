import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError, generateId } from '@/utils/helpers';
import { hashPassword, signToken, verifyPassword } from '@/utils/auth';
import { config } from '@/config/env';
import { profileUpdateSchema, phoneSchema } from '@/types/schemas';
import { toUserSummary } from '@/utils/user-summary';
import { issueOtp, verifyOtp, isMockOtp } from '@/services/otp';
import { recordAudit } from '@/services/audit';

// Tighter abuse protection on the credential endpoints than the global default.
const authRouteConfig = {
  rateLimit: { max: config.authRateLimitMax, timeWindow: config.rateLimitWindow },
};

const registerSchema = z.object({
  email: z.string().email(),
  full_name: z.string().min(2),
  user_type: z.enum(['shopper', 'traveler', 'both']),
  phone: phoneSchema,
  password: z.string().min(8),
});

const verifyOtpSchema = z.object({
  channel: z.enum(['email', 'phone']),
  code: z.string().trim().length(6),
});

const resendOtpSchema = z.object({
  channel: z.enum(['email', 'phone']),
});

const forgotPasswordSchema = z.object({
  email: z.string().email(),
});

const resetPasswordSchema = z.object({
  email: z.string().email(),
  code: z.string().trim().length(6),
  new_password: z.string().min(8),
});

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/auth/register', { config: authRouteConfig }, async (request: any, reply: any) => {
    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidRegistration');
    }

    const existingUser = await request.db
      .selectFrom('users')
      .select('id')
      .where('email', '=', parsed.data.email)
      .executeTakeFirst();

    if (existingUser) {
      throw new AppError('USER_EXISTS', 409, 'auth.userExists');
    }

    const userId = generateId();
    await request.db
      .insertInto('users')
      .values({
        id: userId,
        email: parsed.data.email,
        full_name: parsed.data.full_name,
        user_type: parsed.data.user_type,
        phone: parsed.data.phone,
        kyc_status: 'pending',
        password_hash: hashPassword(parsed.data.password),
        // Explicitly unverified — every route but /api/me and the OTP
        // endpoints is blocked until both codes below are confirmed.
        email_verified_at: null,
        phone_verified_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      })
      .execute();

    const [emailCode, phoneCode] = await Promise.all([
      issueOtp(request.db, userId, 'email', parsed.data.email),
      issueOtp(request.db, userId, 'phone', parsed.data.phone),
    ]);

    const token = signToken({
      userId,
      email: parsed.data.email,
      exp: Date.now() + 1000 * 60 * 60 * 24 * 7,
    });

    reply.status(201).send({
      success: true,
      data: {
        userId,
        email: parsed.data.email,
        token,
        ...(isMockOtp() ? { debug_otp: { email: emailCode, phone: phoneCode } } : {}),
      },
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
      throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidLogin');
    }

    const user = await request.db
      .selectFrom('users')
      .selectAll()
      .where('email', '=', parsed.data.email)
      .executeTakeFirst();

    if (!user || !verifyPassword(parsed.data.password, user.password_hash)) {
      throw new AppError('AUTH_ERROR', 401, 'auth.invalidCredentials');
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

  // Reuses the email OTP channel — "prove you control this address" is the
  // same check whether it's for verifying registration or for resetting a
  // forgotten password. Always responds the same way regardless of whether
  // the email is registered, so this can't be used to enumerate accounts.
  app.post<{ Body: unknown }>(
    '/api/auth/forgot-password',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = forgotPasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidEmail');
      }

      const user = await request.db
        .selectFrom('users')
        .select(['id', 'email'])
        .where('email', '=', parsed.data.email)
        .executeTakeFirst();

      const code = user ? await issueOtp(request.db, user.id, 'email', user.email) : undefined;

      reply.send({
        success: true,
        data: { sent: true, ...(isMockOtp() && code ? { debug_otp: code } : {}) },
        code: 'PASSWORD_RESET_REQUESTED',
      });
    }
  );

  app.post<{ Body: unknown }>(
    '/api/auth/reset-password',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = resetPasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidResetDetails');
      }

      const user = await request.db
        .selectFrom('users')
        .select(['id', 'email'])
        .where('email', '=', parsed.data.email)
        .executeTakeFirst();

      const ok = user ? await verifyOtp(request.db, user.id, 'email', parsed.data.code) : false;
      if (!user || !ok) {
        throw new AppError('INVALID_OTP', 400, 'common.otpInvalid');
      }

      await request.db
        .updateTable('users')
        .set({ password_hash: hashPassword(parsed.data.new_password), updated_at: new Date() })
        .where('id', '=', user.id)
        .execute();

      await recordAudit(request.db, { id: user.id, role: null }, {
        action: 'user.password_reset',
        targetType: 'user',
        targetId: user.id,
        summary: 'Password reset via forgot-password flow',
      });

      const token = signToken({
        userId: user.id,
        email: user.email,
        exp: Date.now() + 1000 * 60 * 60 * 24 * 7,
      });

      reply.send({
        success: true,
        data: { userId: user.id, email: user.email, token },
        code: 'PASSWORD_RESET',
      });
    }
  );

  const meColumns = [
    'id',
    'email',
    'full_name',
    'user_type',
    'role',
    'kyc_status',
    'risk_status',
    'avatar_url',
    'home_city',
    'rating_sum',
    'rating_count',
    'delivered_count',
    'phone',
    'address_street',
    'address_city',
    'address_postal_code',
    'address_country',
    'email_verified_at',
    'phone_verified_at',
    'created_at',
  ] as const;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const meResponse = (me: any): Record<string, unknown> => {
    const summary = toUserSummary(me);
    return {
      ...me,
      rating_avg: summary.rating_avg,
      pilot: {
        manual_money: config.manualMoneyPilot,
        payment_instructions: config.paymentInstructions,
      },
    };
  };

  // The signed-in user's own profile — the front-end calls this on load.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/me', async (request: any, reply: any) => {
    const me = await request.db
      .selectFrom('users')
      .select([...meColumns])
      .where('id', '=', request.userId)
      .executeTakeFirst();

    if (!me) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    reply.send({ success: true, data: meResponse(me), code: 'ME' });
  });

  // Edit your own profile (name, home city, avatar URL, phone, address).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.patch('/api/me', async (request: any, reply: any) => {
    const parsed = profileUpdateSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidProfileUpdate');
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const patch: Record<string, any> = { updated_at: new Date() };
    if (parsed.data.full_name !== undefined) patch.full_name = parsed.data.full_name;
    if (parsed.data.home_city !== undefined) patch.home_city = parsed.data.home_city;
    if (parsed.data.avatar_url !== undefined) patch.avatar_url = parsed.data.avatar_url;
    if (parsed.data.phone !== undefined) patch.phone = parsed.data.phone;
    if (parsed.data.address_street !== undefined) patch.address_street = parsed.data.address_street;
    if (parsed.data.address_city !== undefined) patch.address_city = parsed.data.address_city;
    if (parsed.data.address_postal_code !== undefined) patch.address_postal_code = parsed.data.address_postal_code;
    if (parsed.data.address_country !== undefined) patch.address_country = parsed.data.address_country;

    await request.db.updateTable('users').set(patch).where('id', '=', request.userId).execute();

    const me = await request.db
      .selectFrom('users')
      .select([...meColumns])
      .where('id', '=', request.userId)
      .executeTakeFirst();

    reply.send({ success: true, data: meResponse(me), code: 'ME_UPDATED' });
  });

  // Confirm a code sent at registration (or via resend, below). Every route
  // but /api/me and these two is blocked until both channels are verified —
  // see the auth guard's VERIFICATION_EXEMPT_ROUTES.
  app.post<{ Body: unknown }>(
    '/api/auth/verify-otp',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = verifyOtpSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidVerificationCode');
      }

      const ok = await verifyOtp(request.db, request.userId, parsed.data.channel, parsed.data.code);
      if (!ok) {
        throw new AppError('INVALID_OTP', 400, 'common.otpInvalid');
      }

      const me = await request.db
        .selectFrom('users')
        .select([...meColumns])
        .where('id', '=', request.userId)
        .executeTakeFirst();

      reply.send({ success: true, data: meResponse(me), code: 'OTP_VERIFIED' });
    }
  );

  // Issues a fresh code for one channel (the old one, if any, stops working).
  app.post<{ Body: unknown }>(
    '/api/auth/resend-otp',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request: any, reply: any) => {
      const parsed = resendOtpSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidChannel');
      }

      const me = await request.db
        .selectFrom('users')
        .select(['email', 'phone'])
        .where('id', '=', request.userId)
        .executeTakeFirst();
      if (!me) {
        throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
      }

      const destination = parsed.data.channel === 'email' ? me.email : me.phone;
      if (!destination) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.noPhoneOnFile');
      }

      const code = await issueOtp(request.db, request.userId, parsed.data.channel, destination);

      reply.send({
        success: true,
        data: { sent: true, ...(isMockOtp() ? { debug_otp: code } : {}) },
        code: 'OTP_RESENT',
      });
    }
  );
}
