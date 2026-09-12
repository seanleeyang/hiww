import { t } from '@/i18n/messages';
import type { SupportedLocale } from '@/i18n/locale';

export class AppError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    public key: string,
    public params?: Record<string, string | number>
  ) {
    super(t('en', key, params)); // English for logs/stack traces.
  }

  /** The user-facing message in the caller's locale. */
  localize(locale: SupportedLocale): string {
    return t(locale, this.key, this.params);
  }
}

export function generateId(): string {
  return crypto.randomUUID();
}

/**
 * True for a Postgres unique-constraint violation (error code 23505). The
 * check-then-insert pattern used by e.g. payout/refund recording has a race
 * window between "does one exist yet" and the insert — a DB-level unique
 * constraint on the relevant column is the real backstop against two
 * concurrent requests both getting through, not the earlier check. Without
 * this, the loser of that race surfaces as a raw, unhandled 500 instead of
 * the same clean "already done" error the earlier check would have given it.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function isUniqueViolation(error: any): boolean {
  return error?.code === '23505';
}
