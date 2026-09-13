export function getHealthSummary(): {
  node_env: string;
  payment_provider: string;
  identity_provider: string;
  database_url_present: boolean;
  git_commit: string;
  logtail_configured: boolean;
} {
  return {
    node_env: process.env.NODE_ENV || 'development',
    payment_provider: process.env.PAYMENT_PROVIDER || 'mock',
    identity_provider: process.env.IDENTITY_PROVIDER || 'mock',
    database_url_present: Boolean(process.env.DATABASE_URL),
    // Render sets this automatically on every deploy — lets `/health` answer
    // "which commit is actually live" without dashboard access, e.g. to
    // confirm a deploy actually picked up a newly-added env var.
    git_commit: process.env.RENDER_GIT_COMMIT || 'unknown',
    // Presence only, never the token itself — confirms LOGTAIL_SOURCE_TOKEN
    // actually reached the running process without exposing the secret.
    logtail_configured: Boolean(process.env.LOGTAIL_SOURCE_TOKEN),
  };
}
