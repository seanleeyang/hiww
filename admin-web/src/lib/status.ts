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

export const ORDER_STATUSES = Object.keys(ORDER_STATUS_LABELS) as OrderStatus[];

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

const TRIP_STATUS_LABELS: Record<string, string> = {
  published: 'Published',
  in_progress: 'In progress',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

export function tripStatusLabel(status: string): string {
  return TRIP_STATUS_LABELS[status] ?? status;
}

export const TRIP_STATUSES = Object.keys(TRIP_STATUS_LABELS);

const WANT_STATUS_LABELS: Record<string, string> = {
  open: 'Open',
  accepted: 'Accepted',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

export function wantStatusLabel(status: string): string {
  return WANT_STATUS_LABELS[status] ?? status;
}

export const WANT_STATUSES = Object.keys(WANT_STATUS_LABELS);

const OFFER_STATUS_LABELS: Record<string, string> = {
  pending: 'Pending',
  accepted: 'Accepted',
  rejected: 'Rejected',
  expired: 'Expired',
};

export function offerStatusLabel(status: string): string {
  return OFFER_STATUS_LABELS[status] ?? status;
}

export const OFFER_STATUSES = Object.keys(OFFER_STATUS_LABELS);

/** Shared by trip/want/offer status — they all use the same
 * published-or-open / accepted / completed / rejected-or-expired /
 * cancelled shape, just with different words for each state. */
export function lifecycleTone(status: string): 'neutral' | 'positive' | 'warning' | 'negative' {
  if (status === 'completed' || status === 'accepted') return 'positive';
  if (status === 'cancelled' || status === 'rejected' || status === 'expired') return 'negative';
  return 'neutral';
}

const RISK_STATUS_LABELS: Record<string, string> = {
  clear: 'Clear',
  flagged: 'Flagged',
  restricted: 'Restricted',
};

export function riskStatusLabel(status: string): string {
  return RISK_STATUS_LABELS[status] ?? status;
}

export function riskStatusTone(status: string): 'neutral' | 'positive' | 'warning' | 'negative' {
  if (status === 'clear') return 'positive';
  if (status === 'restricted') return 'negative';
  if (status === 'flagged') return 'warning';
  return 'neutral';
}

/** Mirrors the backend's `AuditAction` union (src/services/audit.ts) so the
 * Audit log's Action filter can be a dropdown instead of asking an admin to
 * remember and type an exact dot-name. Keep the two in sync. */
export const AUDIT_ACTIONS = [
  'order.create',
  'order.payment_claim',
  'order.payment_timeout',
  'offer.counter',
  'offer.decline',
  'offer.expire',
  'payment.confirm',
  'order.purchase_proof',
  'order.receipt_flag',
  'order.receipt_flag_cleared',
  'order.ship',
  'order.shipping_proof',
  'order.release',
  'order.payout',
  'dispute.open',
  'dispute.resolve',
  'kyc.submit',
  'kyc.review',
  'kyc.ai_flag',
  'kyc.ai_check_failed',
  'user.flag',
  'user.password_reset',
  'user.password_change',
  'user.phone_changed',
  'user.email_changed',
  'user.reclaimed_via_social_link',
  'message.flag',
  'message.flag_cleared',
  'message.hidden',
  'message.check_failed',
  'order.receipt_check_failed',
  'trip.update',
  'trip.cancel',
  'trip.delete',
  'trip.archive',
  'trip.remove_by_admin',
  'request.update',
  'request.cancel',
  'request.archive',
  'request.remove_by_admin',
  'order.admin_cancel',
  'order.refund',
  'review.hide',
  'review.unhide',
] as const;
