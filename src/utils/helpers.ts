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
