export const productionConfig = {
  allowedHosts: process.env.ALLOWED_HOSTS?.split(',') || ['localhost', '127.0.0.1'],
  corsOrigin: process.env.CORS_ORIGIN || true,
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || '60000'),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || '120'),
};
