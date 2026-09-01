import 'dotenv/config';

const nodeEnv = process.env.NODE_ENV || 'development';

function requireEnv(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

if (nodeEnv === 'production') {
  requireEnv('DATABASE_URL');
  requireEnv('JWT_SECRET');
}

export const config = {
  nodeEnv,
  port: Number(process.env.PORT || '3000'),
  host: process.env.HOST || '0.0.0.0',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/hiww',
  jwtSecret: process.env.JWT_SECRET || 'dev-secret',
  paymentProvider: process.env.PAYMENT_PROVIDER || 'mock',
  identityProvider: process.env.IDENTITY_PROVIDER || 'mock',
  logLevel: process.env.LOG_LEVEL || 'info',
};
