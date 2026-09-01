import Decimal from 'decimal.js';

export class AppError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    message: string
  ) {
    super(message);
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
