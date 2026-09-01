import { PaymentProvider, PaymentSessionInput, PaymentSessionResult } from './types';

export class OpnPaymentProvider implements PaymentProvider {
  readonly providerName = 'opn_payment_provider';

  async createSession(order: PaymentSessionInput): Promise<PaymentSessionResult> {
    // TODO: replace with real Opn SDK call.
    // Example pattern:
    // const response = await fetch(`${process.env.OPN_API_URL}/sessions`, {
    //   method: 'POST',
    //   headers: {
    //     Authorization: `Bearer ${process.env.OPN_API_KEY}`,
    //     'Content-Type': 'application/json',
    //   },
    //   body: JSON.stringify({
    //     order_id: order.id,
    //     amount: order.total_price,
    //     currency: 'NGN',
    //   }),
    // });

    return {
      payment_id: `opn_${order.id}`,
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
