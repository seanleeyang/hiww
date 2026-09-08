import Decimal from 'decimal.js';
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

export function calculateFees(
  amount: Decimal,
  platformFeePercent: number = 5,
  processingFeePercent: number = 3
): { platformFee: Decimal; processingFee: Decimal; total: Decimal } {
  const platformFee = amount.mul(platformFeePercent).div(100);
  const processingFee = amount.mul(processingFeePercent).div(100);
  const total = amount.add(platformFee).add(processingFee);

  return {
    platformFee,
    processingFee,
    total,
  };
}

export function generateId(): string {
  return crypto.randomUUID();
}
