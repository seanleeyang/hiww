import Decimal from 'decimal.js';
import { AppError } from '@/utils/helpers';

/**
 * MVP pricing model. The shopper pays for the item, a traveller reward, and
 * a service fee; the traveller receives item + reward (never docked for the
 * platform's cut); the platform's revenue is the service fee alone. Named
 * constants here so nothing is scattered as a magic number elsewhere.
 */
export const TRAVELLER_REWARD_MIN_THB = 50;
export const TRAVELLER_REWARD_RATE = 0.1;
export const SERVICE_FEE_RATE = 0.1;
export const DEFAULT_CURRENCY = 'THB';

export interface PricingBreakdown {
  itemPrice: string;
  travellerReward: string;
  serviceFee: string;
  shopperTotal: string;
  travellerPayout: string;
  platformGrossRevenue: string;
  currency: string;
}

/**
 * The single source of truth for every money split in the app — order
 * creation, checkout display, offer/negotiation previews, payment
 * processing, payout, and admin views must all call this rather than
 * recompute any of these numbers themselves.
 */
export function calculatePricing(itemPrice: string | number): PricingBreakdown {
  const price = new Decimal(itemPrice);
  if (price.isNaN() || price.isNegative()) {
    throw new AppError('VALIDATION_ERROR', 400, 'pricing.invalidItemPrice');
  }

  const reward = Decimal.max(TRAVELLER_REWARD_MIN_THB, price.mul(TRAVELLER_REWARD_RATE)).toDecimalPlaces(2);
  const fee = price.mul(SERVICE_FEE_RATE).toDecimalPlaces(2);
  const shopperTotal = price.plus(reward).plus(fee).toDecimalPlaces(2);
  const travellerPayout = price.plus(reward).toDecimalPlaces(2);

  return {
    itemPrice: price.toDecimalPlaces(2).toString(),
    travellerReward: reward.toString(),
    serviceFee: fee.toString(),
    shopperTotal: shopperTotal.toString(),
    travellerPayout: travellerPayout.toString(),
    platformGrossRevenue: fee.toString(),
    currency: DEFAULT_CURRENCY,
  };
}
