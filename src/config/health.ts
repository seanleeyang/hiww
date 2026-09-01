export function getHealthSummary() {
  return {
    node_env: process.env.NODE_ENV || 'development',
    payment_provider: process.env.PAYMENT_PROVIDER || 'mock',
    identity_provider: process.env.IDENTITY_PROVIDER || 'mock',
    database_url_present: Boolean(process.env.DATABASE_URL),
  };
}
