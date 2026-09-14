import 'dotenv/config';

const nodeEnv = process.env.NODE_ENV || 'development';

const WEAK_SECRETS = new Set([
  'dev-secret',
  'dev-secret-change-me',
  'test-secret',
  'your-secret',
  'your-secret-key-here',
  'your-secret-key-here-change-in-production',
  'changeme',
]);

function requireEnv(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

/**
 * Resolve the signing secret used for auth tokens.
 *
 * The secret must be present and non-trivial in every environment except the
 * automated test run, where a fixed throwaway value keeps CI hermetic. A weak or
 * missing secret means anyone can mint valid login tokens, so we fail fast
 * rather than boot in an insecure state.
 */
function resolveJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  const isStrong = typeof secret === 'string' && secret.length >= 24 && !WEAK_SECRETS.has(secret);

  if (isStrong) {
    return secret as string;
  }

  if (nodeEnv === 'test') {
    return 'test-only-secret-not-valid-for-any-real-environment';
  }

  throw new Error(
    'JWT_SECRET is missing or too weak. Generate a strong random value ' +
      "(e.g. `node -e \"console.log(require('crypto').randomBytes(48).toString('base64url'))\"`) " +
      'and set it as JWT_SECRET.'
  );
}

/**
 * Resolve the key that encrypts sensitive fields at rest (bank account
 * numbers — see src/utils/encryption.ts). Deliberately a separate secret
 * from JWT_SECRET: rotating the login secret (e.g. after an incident) must
 * never also make every stored bank account unreadable. Same fail-fast
 * posture as the JWT secret — a missing/weak key here is worse than a
 * crash, since it would mean either booting with no encryption or silently
 * encrypting with a guessable key.
 */
function resolveDataEncryptionKey(): string {
  const key = process.env.DATA_ENCRYPTION_KEY;
  const isStrong = typeof key === 'string' && key.length >= 24 && !WEAK_SECRETS.has(key);

  if (isStrong) {
    return key as string;
  }

  if (nodeEnv === 'test') {
    return 'test-only-encryption-key-not-valid-for-any-real-environment';
  }

  throw new Error(
    'DATA_ENCRYPTION_KEY is missing or too weak. Generate a strong random value ' +
      "(e.g. `node -e \"console.log(require('crypto').randomBytes(48).toString('base64url'))\"`) " +
      'and set it as DATA_ENCRYPTION_KEY. Back this up somewhere safe — losing it makes every ' +
      'already-encrypted value (e.g. stored bank account numbers) permanently unreadable.'
  );
}

if (nodeEnv === 'production') {
  requireEnv('DATABASE_URL');
}

export const config = {
  nodeEnv,
  port: Number(process.env.PORT || '3000'),
  host: process.env.HOST || '0.0.0.0',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hiww',
  jwtSecret: resolveJwtSecret(),
  dataEncryptionKey: resolveDataEncryptionKey(),
  paymentProvider: process.env.PAYMENT_PROVIDER || 'mock',
  identityProvider: process.env.IDENTITY_PROVIDER || 'mock',
  logLevel: process.env.LOG_LEVEL || 'info',
  /**
   * Ships every production log line to Better Stack (Logtail) in addition to
   * stdout (which Render's own log viewer already captures), for searchable
   * history and alerting beyond "whatever recently scrolled by". Both values
   * come from the same "Connect source" screen when creating a Node.js/Pino
   * source in Better Stack. Optional — with no token set, logging behaves
   * exactly as before (plain stdout JSON, no shipping).
   */
  logtailSourceToken: process.env.LOGTAIL_SOURCE_TOKEN || '',
  logtailEndpoint: process.env.LOGTAIL_ENDPOINT || 'https://in.logs.betterstack.com',
  /**
   * Shared secret a Cloudflare Transform Rule stamps onto every request it
   * proxies (header `X-Origin-Secret`) — lets the app reject any request
   * that reached it directly, bypassing Cloudflare (see docs/DEPLOY.md).
   * Empty (default) disables the check entirely; only set this once the
   * Cloudflare side is actually configured with the matching rule, or every
   * request — including your own — will be rejected.
   */
  cloudflareOriginSecret: process.env.CLOUDFLARE_ORIGIN_SECRET || '',
  // Abuse protection. Counts are per client IP per window.
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || '200'),
  rateLimitWindow: process.env.RATE_LIMIT_WINDOW || '1 minute',
  authRateLimitMax: Number(process.env.AUTH_RATE_LIMIT_MAX || '20'),
  // Tighter per-IP ceilings on the sensitive routes: money movement, order
  // creation, and file uploads.
  moneyRateLimitMax: Number(process.env.MONEY_RATE_LIMIT_MAX || '30'),
  uploadRateLimitMax: Number(process.env.UPLOAD_RATE_LIMIT_MAX || '20'),
  /**
   * During the manual-money pilot the platform does not move funds automatically.
   * Payment capture and payout are recorded by an admin after they settle money
   * out-of-band. Set MANUAL_MONEY_PILOT=false only once a real payment provider
   * and double-entry ledger are wired up.
   */
  manualMoneyPilot: process.env.MANUAL_MONEY_PILOT !== 'false',
  /**
   * Shown to shoppers on the "pay" screen during the manual-money pilot. Put
   * your bank / Wise / PromptPay details here (via the PILOT_PAYMENT_INSTRUCTIONS
   * env var — keep account numbers out of source control).
   */
  paymentInstructions:
    process.env.PILOT_PAYMENT_INSTRUCTIONS ||
    'Payment instructions have not been configured yet. Contact the Hiww team to arrange payment.',
  /**
   * Minutes a shopper has to pay after their offer is accepted before the
   * order auto-cancels (see `src/services/order-expiry.ts`). There's no
   * background job — the deadline is only enforced lazily, the moment an
   * order is next read or acted on.
   */
  paymentTimeoutMinutes: Number(process.env.PAYMENT_TIMEOUT_MINUTES || '60'),
  /**
   * Hours either side has to respond to an offer/counter before it
   * auto-expires (see `src/services/offer-expiry.ts`) — keeps a negotiation
   * from stalling indefinitely. Same lazy-enforcement pattern as
   * `paymentTimeoutMinutes`: no background job, checked on next read.
   */
  offerResponseTimeoutHours: Number(process.env.OFFER_RESPONSE_TIMEOUT_HOURS || '24'),
  /** Total counter-offers allowed in one negotiation before it must resolve
   * (accept or decline) — see `POST /api/offers/:id/counter`. */
  maxOfferCounters: Number(process.env.MAX_OFFER_COUNTERS || '2'),
  /**
   * During the manual-money pilot, how many days a delivered order can sit
   * with no payout recorded (or a cancelled-and-confirmed order with no
   * refund recorded) before `GET /api/ops/reconciliation` marks it overdue
   * — a nudge for the operator to prioritize, not an enforced deadline.
   */
  payoutOverdueDays: Number(process.env.PAYOUT_OVERDUE_DAYS || '3'),
  /**
   * User-uploaded images (want photos, trip covers, avatars). Local disk during
   * the pilot; swap for object storage (S3/GCS) before production. `uploadDir`
   * is resolved from the process working directory (the project root).
   */
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  maxUploadBytes: Number(process.env.MAX_UPLOAD_BYTES || String(5 * 1024 * 1024)),
  /**
   * Absolute origin used to build URLs for uploaded files. Leave empty to derive
   * it from each request (works for localhost, a LAN IP and a dev tunnel alike);
   * set it once there is a stable public hostname behind a proxy.
   */
  publicBaseUrl: (process.env.PUBLIC_BASE_URL || '').replace(/\/+$/, ''),
  /**
   * Where uploaded images live. `local` writes to `uploadDir` on disk and serves
   * them from `/uploads/*` (fine for dev; the disk is ephemeral on Render's free
   * tier, so images vanish on every redeploy). `r2` stores them in a Cloudflare
   * R2 bucket over the S3 API and serves them from `r2PublicBaseUrl` — use this
   * in production. Needs the four R2_* values below.
   */
  uploadsBackend: process.env.UPLOADS_BACKEND || 'local',
  r2AccountId: process.env.R2_ACCOUNT_ID || '',
  r2AccessKeyId: process.env.R2_ACCESS_KEY_ID || '',
  r2SecretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
  r2Bucket: process.env.R2_BUCKET || '',
  // Public origin the bucket is served from — the r2.dev dev URL or a custom
  // domain, no trailing slash.
  r2PublicBaseUrl: (process.env.R2_PUBLIC_BASE_URL || '').replace(/\/+$/, ''),
  /**
   * AI receipt check. When the traveller uploads a shop receipt, an analyzer
   * extracts the merchant/date/total and flags anything suspicious for the
   * operator. `mock` (default) is a deterministic stand-in used by tests and
   * local dev; `claude` calls the Anthropic API and needs ANTHROPIC_API_KEY.
   * It is advisory only — it never blocks the order.
   */
  aiReceiptAnalyzer: process.env.AI_RECEIPT_ANALYZER || 'mock',
  aiModel: process.env.AI_MODEL || 'claude-opus-5',
  anthropicApiKey: process.env.ANTHROPIC_API_KEY || '',
  /**
   * AI chat moderation. Every message posted to an order's chat is checked
   * for contact-info/payment "leakage" attempts (moving the deal off-platform)
   * and abusive behaviour. `mock` (default) is deterministic for tests and
   * local dev; `claude` calls the Anthropic API and needs ANTHROPIC_API_KEY.
   * Advisory only — a flagged message still sends, it just surfaces a warning
   * to the sender and puts the message in the admin review queue.
   */
  aiChatModeration: process.env.AI_CHAT_MODERATION || 'mock',
  aiChatModel: process.env.AI_CHAT_MODEL || 'claude-haiku-4-5',
  /**
   * AI KYC check. Cross-checks a submitted ID-check form (name, document
   * number, address) against what's printed on the uploaded document photo,
   * checks the selfie-with-document photo for a face match, and flags an
   * obviously inauthentic document — advisory only, an admin still makes
   * the final approve/reject call. `mock` (default) is deterministic for
   * tests and local dev; `claude` calls the Anthropic API and needs
   * ANTHROPIC_API_KEY. Uses the same higher-capability model tier as the
   * receipt check (not the lighter chat-moderation one) since document/face
   * comparison is a harder vision task.
   */
  aiKycCheck: process.env.AI_KYC_CHECK || 'mock',
  aiKycModel: process.env.AI_KYC_MODEL || 'claude-opus-5',
  /**
   * AI image moderation. Runs on every `POST /api/uploads` — want/item
   * photos, trip cover photos, avatars — the only image types with no other
   * automated review (receipts, KYC documents, and chat photos each already
   * get their own dedicated check elsewhere). Unlike those, this one is NOT
   * advisory: an upload scored "high" risk (unambiguous explicit/graphic
   * content) is rejected outright before it's ever stored, the same way a
   * QR code in a chat photo is rejected outright (see src/services/qr-check.ts)
   * rather than merely flagged — this is content that must never go public,
   * not a judgment call worth leaving to a human review queue. "medium"
   * (borderline/ambiguous) still uploads normally but is logged to the audit
   * trail for an operator to spot-check. Also screens for content related to
   * the Thai monarchy — this app operates in Thailand, where disrespectful
   * content about the royal family carries real criminal liability
   * (lèse-majesté) for both the poster and the platform; see the prompt in
   * claude-image-moderation-analyzer.ts for exactly where that line is
   * drawn. `mock` (default) is deterministic for tests and local dev;
   * `claude` calls the Anthropic API and needs ANTHROPIC_API_KEY. Uses the
   * higher-capability model tier, same reasoning as the KYC check above.
   */
  aiImageModeration: process.env.AI_IMAGE_MODERATION || 'mock',
  aiImageModerationModel: process.env.AI_IMAGE_MODERATION_MODEL || 'claude-opus-5',
  /**
   * Push notifications ("hard" alerts a user gets even with the app fully
   * closed), for the two things that can't wait for the next in-app poll:
   * the shopper's payment countdown starting, and the traveler's daily
   * upload-photo/receipt nudge. `mock` (default) just logs instead of
   * calling a real provider — used by tests and local dev. `fcm` sends via
   * Firebase Cloud Messaging and needs FIREBASE_SERVICE_ACCOUNT_JSON (the
   * full JSON key from a Firebase service account, as one env var — see
   * mobile/lib/firebase_options.dart for the matching client-side setup).
   */
  pushProvider: process.env.PUSH_PROVIDER || 'mock',
  firebaseServiceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '',
  /**
   * Email/phone verification at registration (see `src/services/otp/`).
   * `mock` (default) logs the code server-side instead of sending it, and
   * the register/resend-otp responses echo it back as `debug_otp` so local
   * dev and scripts can complete verification without a real inbox/SMS —
   * that echo is skipped the moment a real provider is wired in here.
   * No real provider is implemented yet; wire one in `src/services/otp/`
   * (e.g. Twilio for SMS, any transactional-email API) and read its
   * credentials from new env vars the same way ANTHROPIC_API_KEY is read.
   */
  otpProvider: process.env.OTP_PROVIDER || 'mock',
  /**
   * Social sign-in. Each provider is independently optional — `POST
   * /api/auth/social` 501s with a clear "not configured" error for a
   * provider whose value is empty here, so providers go live one at a time
   * as credentials arrive. `googleClientId` is the Google Cloud OAuth 2.0
   * Web application Client ID; the mobile app sends an ID token whose `aud`
   * claim must match this value (verified server-side, never trusted from
   * the client).
   */
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  /**
   * LINE Login. Unlike Google's ID-token flow, LINE uses an OAuth
   * authorization-code redirect — the mobile app sends the `code` it got
   * back from LINE, and the backend exchanges it for an id_token using the
   * channel secret (never exposed to the client) before verifying it with
   * LINE's own /oauth2/v2.1/verify endpoint. `lineCallbackUrl` must exactly
   * match a Callback URL registered on the channel (LINE Developers Console
   * → your channel → LINE Login → Callback URL) — including the one used
   * for local dev, since the redirect_uri sent in the token exchange must
   * match whichever origin the client was actually redirected from.
   */
  lineChannelId: process.env.LINE_CHANNEL_ID || '',
  lineChannelSecret: process.env.LINE_CHANNEL_SECRET || '',
  /**
   * Facebook Login. Same OAuth authorization-code redirect shape as LINE
   * above (Facebook has no client-side ID token either) — the mobile app
   * sends the `code` it got back from Facebook, and the backend exchanges
   * it for an access token via the Graph API using the app secret (never
   * exposed to the client), then calls `/me` with that token to get the
   * verified identity. `facebookRedirectUri`s equivalent must be registered
   * as a Valid OAuth Redirect URI under the app's Authentication use case
   * (developers.facebook.com → your app → Use cases → Authentication →
   * Settings) for both the deployed origin and local dev.
   */
  facebookAppId: process.env.FACEBOOK_APP_ID || '',
  facebookAppSecret: process.env.FACEBOOK_APP_SECRET || '',
};
