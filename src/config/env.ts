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
  /**
   * During the manual-money pilot the platform does not move funds automatically.
   * Payment capture and payout are recorded by an admin after they settle money
   * out-of-band. Set MANUAL_MONEY_PILOT=false only once a real payment provider
   * and double-entry ledger are wired up.
   */
  manualMoneyPilot: process.env.MANUAL_MONEY_PILOT !== 'false',
};
