import type { OrderStatus } from '../api/types';

// Mirrors the mobile app's order-stepper labels (mobile/lib/l10n/app_en.arb:
// stageAcceptedTitle etc.) so admin staff see the same vocabulary a shopper
// or traveler sees, instead of the raw DB status string.
const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  pending_payment: 'Awaiting payment',
  confirmed: 'Paid',
  purchased: 'Items purchased',
  in_transit: 'In transit',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};

export function orderStatusLabel(status: string): string {
  return ORDER_STATUS_LABELS[status as OrderStatus] ?? status;
}

export function orderStatusTone(status: string): 'neutral' | 'positive' | 'warning' | 'negative' {
  if (status === 'delivered') return 'positive';
  if (status === 'cancelled') return 'negative';
  if (status === 'pending_payment') return 'warning';
  return 'neutral';
}

const RISK_LABELS: Record<string, string> = {
  low: 'Low risk',
  medium: 'Medium risk',
  high: 'High risk',
};

export function riskLabel(risk: string): string {
  return RISK_LABELS[risk] ?? risk;
}

export function riskTone(risk: string): 'neutral' | 'warning' | 'negative' {
  if (risk === 'high') return 'negative';
  if (risk === 'medium') return 'warning';
  return 'neutral';
}

const KYC_LABELS: Record<string, string> = {
  pending: 'Pending',
  approved: 'Approved',
  rejected: 'Rejected',
};

export function idCheckLabel(status: string): string {
  return KYC_LABELS[status] ?? status;
}
