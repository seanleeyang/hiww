export function getHealthSummary(): {
  node_env: string;
  payment_provider: string;
  identity_provider: string;
  database_url_present: boolean;
} {
  return {
    node_env: process.env.NODE_ENV || 'development',
    payment_provider: process.env.PAYMENT_PROVIDER || 'mock',
    identity_provider: process.env.IDENTITY_PROVIDER || 'mock',
    database_url_present: Boolean(process.env.DATABASE_URL),
  };
}
