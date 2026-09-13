import pino from 'pino';
import type { FastifyBaseLogger } from 'fastify';
import { config } from '@/config/env';

/**
 * Production logger: fans every log line out to both stdout (Render's own
 * viewer, same JSON output as before) and Better Stack (Logtail), so errors
 * are searchable and alertable instead of only visible in whatever recently
 * scrolled by. Safe fallback — with no LOGTAIL_SOURCE_TOKEN set, returns
 * `true` and Fastify builds its own plain stdout-JSON pino logger exactly as
 * it did before Logtail was wired in.
 */
export function buildProductionLogger(): true | FastifyBaseLogger {
  if (!config.logtailSourceToken) {
    return true;
  }

  const transport = pino.transport({
    targets: [
      {
        target: '@logtail/pino',
        level: config.logLevel,
        options: {
          sourceToken: config.logtailSourceToken,
          options: { endpoint: config.logtailEndpoint },
        },
      },
      {
        target: 'pino/file',
        level: config.logLevel,
        options: { destination: 1 },
      },
    ],
  });

  return pino({ level: config.logLevel }, transport);
}
