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

if (nodeEnv === 'production') {
  requireEnv('DATABASE_URL');
}

export const config = {
  nodeEnv,
  port: Number(process.env.PORT || '3000'),
  host: process.env.HOST || '0.0.0.0',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hiww',
  jwtSecret: resolveJwtSecret(),
  paymentProvider: process.env.PAYMENT_PROVIDER || 'mock',
  identityProvider: process.env.IDENTITY_PROVIDER || 'mock',
  logLevel: process.env.LOG_LEVEL || 'info',
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
};
