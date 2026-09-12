import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { OAuth2Client } from 'google-auth-library';
import { AppError, generateId } from '@/utils/helpers';
import { hashPassword, signToken, verifyPassword } from '@/utils/auth';
import { config } from '@/config/env';
import { profileUpdateSchema, phoneSchema, passwordSchema } from '@/types/schemas';
import { toUserSummary } from '@/utils/user-summary';
import { membershipId } from '@/utils/membership';
import { issueOtp, verifyOtp, isMockOtp } from '@/services/otp';
import { recordAudit, actorFromRequest } from '@/services/audit';

// Tighter abuse protection on the credential endpoints than the global default.
const authRouteConfig = {
  rateLimit: { max: config.authRateLimitMax, timeWindow: config.rateLimitWindow },
};

const registerSchema = z.object({
  email: z.string().email(),
  full_name: z.string().min(2),
  user_type: z.enum(['shopper', 'traveler', 'both']),
  phone: phoneSchema,
  password: passwordSchema,
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
  new_password: passwordSchema,
});

const changePasswordSchema = z.object({
  current_password: z.string().min(1),
  new_password: passwordSchema,
});

const socialLoginSchema = z.object({
  provider: z.enum(['google', 'apple', 'facebook', 'line']),
  token: z.string().min(1),
  // LINE only: the exact redirect_uri the client used to start the
  // authorize request, so the backend's token exchange (a second call to
  // LINE using the same value) doesn't get rejected as a mismatch. Unused by
  // the other providers, whose flows don't involve a redirect.
  redirect_uri: z.string().url().optional(),
  user_type: z.enum(['shopper', 'traveler', 'both']).optional(),
});

interface VerifiedIdentity {
  providerId: string;
  email: string;
  emailVerified: boolean;
  fullName: string | null;
}

async function verifyGoogleToken(token: string): Promise<VerifiedIdentity> {
  if (!config.googleClientId) {
    throw new AppError('NOT_IMPLEMENTED', 501, 'auth.socialProviderNotConfigured');
  }
  try {
    const client = new OAuth2Client(config.googleClientId);
    const ticket = await client.verifyIdToken({ idToken: token, audience: config.googleClientId });
    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email) {
      throw new Error('missing sub/email in token payload');
    }
    return {
      providerId: payload.sub,
      email: payload.email,
      emailVerified: payload.email_verified === true,
      fullName: payload.name ?? null,
    };
  } catch {
    throw new AppError('AUTH_ERROR', 401, 'auth.invalidSocialToken');
  }
}

// LINE's ID tokens are HS256-signed with the channel secret, not
// RS256-against-a-JWKS like Google/Apple — rather than reimplement HMAC
// verification, this uses LINE's own /oauth2/v2.1/verify endpoint, which
// checks the signature and expiry server-side and hands back the claims.
async function verifyLineToken(code: string, redirectUri: string | undefined): Promise<VerifiedIdentity> {
  if (!config.lineChannelId || !config.lineChannelSecret) {
    throw new AppError('NOT_IMPLEMENTED', 501, 'auth.socialProviderNotConfigured');
  }
  if (!redirectUri) {
    throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidSocialPayload');
  }

  try {
    const tokenRes = await fetch('https://api.line.me/oauth2/v2.1/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: redirectUri,
        client_id: config.lineChannelId,
        client_secret: config.lineChannelSecret,
      }),
    });
    if (!tokenRes.ok) throw new Error(`line token exchange failed: ${tokenRes.status}`);
    const tokenBody = (await tokenRes.json()) as { id_token?: string };
    if (!tokenBody.id_token) throw new Error('missing id_token in line token response');

    const verifyRes = await fetch('https://api.line.me/oauth2/v2.1/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ id_token: tokenBody.id_token, client_id: config.lineChannelId }),
    });
    if (!verifyRes.ok) throw new Error(`line id_token verify failed: ${verifyRes.status}`);
    const claims = (await verifyRes.json()) as { sub?: string; email?: string; name?: string };
    if (!claims.sub) throw new Error('missing sub in verified line claims');

    // LINE only includes `email` if the channel has been granted the
    // "Email address permission" in the LINE Developers Console (a separate
    // application, reviewed by LINE) *and* the user consented to share it.
    // Without it there's nothing to key a `users.email` row on.
    if (!claims.email) {
      throw new AppError('VALIDATION_ERROR', 400, 'auth.socialEmailRequired');
    }

    return {
      providerId: claims.sub,
      email: claims.email,
      emailVerified: true,
      fullName: claims.name ?? null,
    };
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError('AUTH_ERROR', 401, 'auth.invalidSocialToken');
  }
}

// Facebook has no client-side ID token like Google's — same OAuth
// authorization-code redirect shape as LINE above, but via the Graph API
// instead of a dedicated /verify endpoint: we exchange the code for an
// access token ourselves (using the app secret, never exposed to the
// client), which is already trust-anchored by that exchange, then read the
// identity straight off `/me` with that token.
async function verifyFacebookToken(code: string, redirectUri: string | undefined): Promise<VerifiedIdentity> {
  if (!config.facebookAppId || !config.facebookAppSecret) {
    throw new AppError('NOT_IMPLEMENTED', 501, 'auth.socialProviderNotConfigured');
  }
  if (!redirectUri) {
    throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidSocialPayload');
  }

  try {
    const tokenUrl = new URL('https://graph.facebook.com/v21.0/oauth/access_token');
    tokenUrl.searchParams.set('client_id', config.facebookAppId);
    tokenUrl.searchParams.set('client_secret', config.facebookAppSecret);
    tokenUrl.searchParams.set('redirect_uri', redirectUri);
    tokenUrl.searchParams.set('code', code);
    const tokenRes = await fetch(tokenUrl);
    if (!tokenRes.ok) throw new Error(`facebook token exchange failed: ${tokenRes.status}`);
    const tokenBody = (await tokenRes.json()) as { access_token?: string };
    if (!tokenBody.access_token) throw new Error('missing access_token in facebook token response');

    const meUrl = new URL('https://graph.facebook.com/me');
    meUrl.searchParams.set('fields', 'id,name,email');
    meUrl.searchParams.set('access_token', tokenBody.access_token);
    const meRes = await fetch(meUrl);
    if (!meRes.ok) throw new Error(`facebook /me failed: ${meRes.status}`);
    const me = (await meRes.json()) as { id?: string; name?: string; email?: string };
    if (!me.id) throw new Error('missing id in facebook /me response');

    // Facebook only returns `email` if the user has one on file and
    // consented to the `email` permission — without it there's nothing to
    // key a `users.email` row on, same gap as LINE's optional email grant.
    if (!me.email) {
      throw new AppError('VALIDATION_ERROR', 400, 'auth.socialEmailRequired');
    }

    return {
      providerId: me.id,
      email: me.email,
      emailVerified: true,
      fullName: me.name ?? null,
    };
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError('AUTH_ERROR', 401, 'auth.invalidSocialToken');
  }
}

let verifierOverride:
  | ((
      provider: 'google' | 'apple' | 'facebook' | 'line',
      token: string,
      redirectUri: string | undefined
    ) => Promise<VerifiedIdentity>)
  | undefined;

/** Test seam — avoids real Google/LINE network calls when testing the
 * account-linking logic that runs after verification. */
export function __setSocialTokenVerifier(fn: typeof verifierOverride): void {
  verifierOverride = fn;
}

/** Verifies a provider's token server-side and returns the identity it
 * actually attests to — the client's own claims about who it is are never
 * trusted. Throws AppError on anything that doesn't check out. */
async function verifySocialToken(
  provider: 'google' | 'apple' | 'facebook' | 'line',
  token: string,
  redirectUri: string | undefined
): Promise<VerifiedIdentity> {
  if (verifierOverride) return verifierOverride(provider, token, redirectUri);
  if (provider === 'google') return verifyGoogleToken(token);
  if (provider === 'line') return verifyLineToken(token, redirectUri);
  if (provider === 'facebook') return verifyFacebookToken(token, redirectUri);
  throw new AppError('NOT_IMPLEMENTED', 501, 'auth.socialProviderNotConfigured');
}

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  app.post<{ Body: unknown }>('/api/auth/register', { config: authRouteConfig }, async (request, reply) => {
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
      tokenVersion: 0,
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

  app.post<{ Body: unknown }>('/api/auth/login', { config: authRouteConfig }, async (request, reply) => {
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
      tokenVersion: user.token_version,
    });

    reply.send({
      success: true,
      data: { userId: user.id, email: user.email, token },
      code: 'USER_LOGGED_IN',
    });
  });

  // One flow for both sign-up and sign-in: the provider's token is the only
  // proof of identity needed either way, so there's no separate "register
  // with Google" endpoint. `user_type` only matters the first time (a brand
  // new account) — a returning user's existing value is left alone.
  app.post<{ Body: unknown }>(
    '/api/auth/social',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = socialLoginSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidSocialPayload');
      }

      const identity = await verifySocialToken(parsed.data.provider, parsed.data.token, parsed.data.redirect_uri);

      let user = await request.db
        .selectFrom('users')
        .selectAll()
        .where('auth_provider', '=', parsed.data.provider)
        .where('provider_user_id', '=', identity.providerId)
        .executeTakeFirst();

      if (!user) {
        // Not linked yet — if a verified email matches an existing
        // email/password account, link this provider to it instead of
        // creating a duplicate. An unverified provider email can't be used
        // to claim someone else's account this way.
        const existing = identity.emailVerified
          ? await request.db
              .selectFrom('users')
              .selectAll()
              .where('email', '=', identity.email)
              .executeTakeFirst()
          : undefined;

        if (existing) {
          // If this row's email was never itself verified (e.g. someone
          // registered with this email and password but never completed the
          // OTP step — nothing proved they actually own the address), its
          // password proves nothing about who the rightful owner is. A
          // provider that DID verify the email now claiming it is the
          // stronger proof, so the row is reclaimed for them: link the
          // provider and clear the old password hash so whoever set it can
          // no longer sign in as this account. They can set a new password
          // later via the email-OTP-gated reset flow if they want one.
          const reclaiming = !existing.email_verified_at;
          await request.db
            .updateTable('users')
            .set({
              auth_provider: parsed.data.provider,
              provider_user_id: identity.providerId,
              email_verified_at: existing.email_verified_at ?? new Date(),
              // Reclaiming means whoever set that password no longer owns
              // this account — any token issued to them before now (the
              // registration flow signs one immediately, before
              // verification) needs to stop working, same as a password
              // change/reset.
              ...(reclaiming ? { password_hash: null, token_version: existing.token_version + 1 } : {}),
              updated_at: new Date(),
            })
            .where('id', '=', existing.id)
            .execute();
          if (reclaiming) {
            await recordAudit(request.db, actorFromRequest(request), {
              action: 'user.reclaimed_via_social_link',
              targetType: 'user',
              targetId: existing.id,
              summary: `A verified ${parsed.data.provider} login reclaimed a previously-unverified account registered with the same email — old password invalidated`,
              metadata: { provider: parsed.data.provider, email: identity.email },
            });
          }
          user = {
            ...existing,
            auth_provider: parsed.data.provider,
            provider_user_id: identity.providerId,
            ...(reclaiming ? { password_hash: null, token_version: existing.token_version + 1 } : {}),
          };
        } else {
          const userId = generateId();
          const now = new Date();
          await request.db
            .insertInto('users')
            .values({
              id: userId,
              email: identity.email,
              full_name: identity.fullName || identity.email.split('@')[0],
              user_type: parsed.data.user_type ?? 'both',
              kyc_status: 'pending',
              auth_provider: parsed.data.provider,
              provider_user_id: identity.providerId,
              email_verified_at: identity.emailVerified ? now : null,
              phone_verified_at: null,
              created_at: now,
              updated_at: now,
            })
            .execute();
          user = await request.db.selectFrom('users').selectAll().where('id', '=', userId).executeTakeFirstOrThrow();
        }
      }

      const token = signToken({
        userId: user.id,
        email: user.email,
        exp: Date.now() + 1000 * 60 * 60 * 24 * 7,
        tokenVersion: user.token_version,
      });

      reply.send({
        success: true,
        data: { userId: user.id, email: user.email, token },
        code: 'SOCIAL_LOGIN',
      });
    }
  );

  // Reuses the email OTP channel — "prove you control this address" is the
  // same check whether it's for verifying registration or for resetting a
  // forgotten password. Always responds the same way regardless of whether
  // the email is registered, so this can't be used to enumerate accounts.
  app.post<{ Body: unknown }>(
    '/api/auth/forgot-password',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
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
    async (request, reply) => {
      const parsed = resetPasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidResetDetails');
      }

      const user = await request.db
        .selectFrom('users')
        .select(['id', 'email', 'token_version'])
        .where('email', '=', parsed.data.email)
        .executeTakeFirst();

      const ok = user ? await verifyOtp(request.db, user.id, 'email', parsed.data.code) : false;
      if (!user || !ok) {
        throw new AppError('INVALID_OTP', 400, 'common.otpInvalid');
      }

      // Bumping token_version invalidates every token issued before this
      // reset — the exact case this exists for is a stolen/compromised
      // account: resetting the password should also cut off whoever else
      // might still be signed in, not just block new logins with the old
      // password.
      const newTokenVersion = user.token_version + 1;
      await request.db
        .updateTable('users')
        .set({
          password_hash: hashPassword(parsed.data.new_password),
          token_version: newTokenVersion,
          updated_at: new Date(),
        })
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
        tokenVersion: newTokenVersion,
      });

      reply.send({
        success: true,
        data: { userId: user.id, email: user.email, token },
        code: 'PASSWORD_RESET',
      });
    }
  );

  // Change password while signed in — proves identity via the current
  // password rather than an OTP (that's what /forgot-password is for).
  // Auth-guard already requires authentication for this route; userId is
  // guaranteed set here.
  app.post<{ Body: unknown }>(
    '/api/auth/change-password',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = changePasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidChangePassword');
      }

      const user = await request.db
        .selectFrom('users')
        .select(['id', 'email', 'password_hash', 'token_version'])
        .where('id', '=', request.userId!)
        .executeTakeFirst();

      if (!user || !verifyPassword(parsed.data.current_password, user.password_hash)) {
        throw new AppError('AUTH_ERROR', 401, 'auth.currentPasswordIncorrect');
      }

      // Bumping token_version invalidates every other token for this
      // account (a stolen device, an old forgotten-about session) the
      // instant the password changes — this device's own current token
      // would otherwise stop working on its very next request, so a fresh
      // one (already reflecting the bump) is handed back below instead.
      const newTokenVersion = user.token_version + 1;
      await request.db
        .updateTable('users')
        .set({ password_hash: hashPassword(parsed.data.new_password), token_version: newTokenVersion, updated_at: new Date() })
        .where('id', '=', user.id)
        .execute();

      await recordAudit(request.db, actorFromRequest(request), {
        action: 'user.password_change',
        targetType: 'user',
        targetId: user.id,
        summary: 'Password changed from account settings',
      });

      const token = signToken({
        userId: user.id,
        email: user.email,
        exp: Date.now() + 1000 * 60 * 60 * 24 * 7,
        tokenVersion: newTokenVersion,
      });

      reply.send({ success: true, data: { userId: user.id, token }, code: 'PASSWORD_CHANGED' });
    }
  );

  const meColumns = [
    'id',
    'member_seq',
    'email',
    'full_name',
    'user_type',
    'role',
    'kyc_status',
    // Distinguishes "never submitted" from "submitted, awaiting admin
    // review" — both read as kyc_status 'pending' otherwise. The mobile app
    // uses this to lock the Identity Verification form once a submission is
    // in flight, so a user can't resubmit (and re-trigger the paid AI
    // check) while waiting on review.
    'kyc_submitted_at',
    'risk_status',
    'avatar_url',
    'home_city',
    'rating_sum',
    'rating_count',
    'delivered_count',
    'phone',
    'gender',
    'date_of_birth',
    'address_street',
    'address_street2',
    'address_subdistrict',
    'address_district',
    'address_city',
    'address_postal_code',
    'address_country',
    'bank_name',
    'bank_account_number',
    'email_verified_at',
    'phone_verified_at',
    'created_at',
  ] as const;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const meResponse = (me: any): Record<string, unknown> => {
    const summary = toUserSummary(me);
    const { member_seq, ...rest } = me;
    return {
      ...rest,
      rating_avg: summary.rating_avg,
      membership_id: membershipId(member_seq),
      pilot: {
        manual_money: config.manualMoneyPilot,
        payment_instructions: config.paymentInstructions,
      },
    };
  };

  // The signed-in user's own profile — the front-end calls this on load.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.get('/api/me', async (request, reply) => {
    // Auth-guard already requires authentication for this route (it's only
    // VERIFICATION-exempt, not public) — userId is guaranteed set here.
    const me = await request.db
      .selectFrom('users')
      .select([...meColumns])
      .where('id', '=', request.userId!)
      .executeTakeFirst();

    if (!me) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    reply.send({ success: true, data: meResponse(me), code: 'ME' });
  });

  // Edit your own profile (name, home city, avatar URL, phone, address).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.patch('/api/me', async (request, reply) => {
    const parsed = profileUpdateSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidProfileUpdate');
    }

    const current = await request.db
      .selectFrom('users')
      .select(['email', 'phone'])
      .where('id', '=', request.userId!)
      .executeTakeFirst();
    if (!current) {
      throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
    }

    // A changed number/address was never actually proven to belong to this
    // user — the old verification doesn't carry over. `null` counts as a
    // change too for phone (clearing it clears its verification with it);
    // email can't be cleared (it's the login identifier), so it's always a
    // string when present.
    const phoneChanged = parsed.data.phone !== undefined && parsed.data.phone !== current.phone;
    const emailChanged = parsed.data.email !== undefined && parsed.data.email !== current.email;

    if (emailChanged) {
      const taken = await request.db
        .selectFrom('users')
        .select('id')
        .where('email', '=', parsed.data.email!)
        .where('id', '!=', request.userId!)
        .executeTakeFirst();
      if (taken) {
        throw new AppError('USER_EXISTS', 409, 'auth.userExists');
      }
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const patch: Record<string, any> = { updated_at: new Date() };
    if (parsed.data.full_name !== undefined) patch.full_name = parsed.data.full_name;
    if (parsed.data.home_city !== undefined) patch.home_city = parsed.data.home_city;
    if (parsed.data.avatar_url !== undefined) patch.avatar_url = parsed.data.avatar_url;
    if (parsed.data.email !== undefined) patch.email = parsed.data.email;
    if (parsed.data.phone !== undefined) patch.phone = parsed.data.phone;
    if (parsed.data.gender !== undefined) patch.gender = parsed.data.gender;
    if (parsed.data.date_of_birth !== undefined) patch.date_of_birth = parsed.data.date_of_birth;
    if (parsed.data.address_street !== undefined) patch.address_street = parsed.data.address_street;
    if (parsed.data.address_street2 !== undefined) patch.address_street2 = parsed.data.address_street2;
    if (parsed.data.address_subdistrict !== undefined) {
      patch.address_subdistrict = parsed.data.address_subdistrict;
    }
    if (parsed.data.address_district !== undefined) patch.address_district = parsed.data.address_district;
    if (parsed.data.address_city !== undefined) patch.address_city = parsed.data.address_city;
    if (parsed.data.address_postal_code !== undefined) patch.address_postal_code = parsed.data.address_postal_code;
    if (parsed.data.address_country !== undefined) patch.address_country = parsed.data.address_country;
    if (parsed.data.bank_name !== undefined) patch.bank_name = parsed.data.bank_name;
    if (parsed.data.bank_account_number !== undefined) {
      patch.bank_account_number = parsed.data.bank_account_number;
    }

    // Re-issue an OTP immediately for whichever channel(s) changed, same as
    // registration, rather than leaving the account unverified with no code
    // in flight. `/api/me` itself stays verification-exempt, so this save
    // still succeeds even though it just invalidated a channel — every
    // *other* route now 403s with VERIFICATION_REQUIRED until the new
    // value is confirmed (see the auth guard).
    const debugOtp: { email?: string; phone?: string } = {};
    if (emailChanged) {
      patch.email_verified_at = null;
      debugOtp.email = await issueOtp(request.db, request.userId!, 'email', parsed.data.email!);
    }
    if (phoneChanged) {
      patch.phone_verified_at = null;
      if (parsed.data.phone) {
        debugOtp.phone = await issueOtp(request.db, request.userId!, 'phone', parsed.data.phone);
      }
    }

    await request.db.updateTable('users').set(patch).where('id', '=', request.userId!).execute();

    if (emailChanged) {
      await recordAudit(request.db, actorFromRequest(request), {
        action: 'user.email_changed',
        targetType: 'user',
        targetId: request.userId!,
        summary: 'Email address changed — re-verification required',
      });
    }
    if (phoneChanged) {
      await recordAudit(request.db, actorFromRequest(request), {
        action: 'user.phone_changed',
        targetType: 'user',
        targetId: request.userId!,
        summary: 'Phone number changed — re-verification required',
      });
    }

    const me = await request.db
      .selectFrom('users')
      .select([...meColumns])
      .where('id', '=', request.userId!)
      .executeTakeFirst();

    reply.send({
      success: true,
      data: {
        ...meResponse(me),
        ...(isMockOtp() && Object.keys(debugOtp).length ? { debug_otp: debugOtp } : {}),
      },
      code: 'ME_UPDATED',
    });
  });

  // Confirm a code sent at registration (or via resend, below). Every route
  // but /api/me and these two is blocked until both channels are verified —
  // see the auth guard's VERIFICATION_EXEMPT_ROUTES.
  app.post<{ Body: unknown }>(
    '/api/auth/verify-otp',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = verifyOtpSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidVerificationCode');
      }

      const ok = await verifyOtp(request.db, request.userId!, parsed.data.channel, parsed.data.code);
      if (!ok) {
        throw new AppError('INVALID_OTP', 400, 'common.otpInvalid');
      }

      const me = await request.db
        .selectFrom('users')
        .select([...meColumns])
        .where('id', '=', request.userId!)
        .executeTakeFirst();

      reply.send({ success: true, data: meResponse(me), code: 'OTP_VERIFIED' });
    }
  );

  // Issues a fresh code for one channel (the old one, if any, stops working).
  app.post<{ Body: unknown }>(
    '/api/auth/resend-otp',
    { config: authRouteConfig },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = resendOtpSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.invalidChannel');
      }

      const me = await request.db
        .selectFrom('users')
        .select(['email', 'phone'])
        .where('id', '=', request.userId!)
        .executeTakeFirst();
      if (!me) {
        throw new AppError('NOT_FOUND', 404, 'common.userNotFound');
      }

      const destination = parsed.data.channel === 'email' ? me.email : me.phone;
      if (!destination) {
        throw new AppError('VALIDATION_ERROR', 400, 'auth.noPhoneOnFile');
      }

      const code = await issueOtp(request.db, request.userId!, parsed.data.channel, destination);

      reply.send({
        success: true,
        data: { sent: true, ...(isMockOtp() ? { debug_otp: code } : {}) },
        code: 'OTP_RESENT',
      });
    }
  );
}
