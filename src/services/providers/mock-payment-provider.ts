import { PaymentProvider, PaymentSessionInput, PaymentSessionResult } from './types';

export class MockPaymentProvider implements PaymentProvider {
  readonly providerName = 'mock_payment_provider';

  async createSession(order: PaymentSessionInput): Promise<PaymentSessionResult> {
    return {
      payment_id: `payment_${order.id}`,
      status: 'initiated',
      provider: this.providerName,
    };
  }

  async confirm(_paymentId: string): Promise<{ provider: string; status: string }> {
    return {
      provider: this.providerName,
      status: 'confirmed',
    };
  }
}
