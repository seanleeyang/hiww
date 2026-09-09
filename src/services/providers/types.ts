export type PaymentProviderName = 'mock' | 'opn';
export type IdentityProviderName = 'mock' | 'ndid';

export interface PaymentSessionInput {
  id: string;
  /**
   * The amount to actually charge the shopper — their full total (goods +
   * traveller reward + service fee, `order.shopper_total`), not the goods
   * price alone. Named `total_price` for historical reasons; don't confuse
   * it with `orders.total_price` (the DB column, which is goods-only).
   */
  total_price: string;
  shopper_id: string;
  traveler_id: string;
  item_description: string;
}

export interface PaymentSessionResult {
  payment_id: string;
  status: string;
  provider: string;
}

export interface IdentityVerificationResult {
  provider: string;
  status: 'verified' | 'rejected';
  user_id: string;
  document_type: string;
  document_id: string;
}

export interface PaymentProvider {
  readonly providerName: string;
  createSession(order: PaymentSessionInput): Promise<PaymentSessionResult>;
  confirm(paymentId: string): Promise<{ provider: string; status: string }>;
}

export interface IdentityProvider {
  readonly providerName: string;
  verify(userId: string, documentType: string, documentId: string): Promise<IdentityVerificationResult>;
}
