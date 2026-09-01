import { PaymentProvider, IdentityProvider, PaymentProviderName, IdentityProviderName } from './types';
import { MockPaymentProvider } from './mock-payment-provider';
import { OpnPaymentProvider } from './opn-payment-provider';
import { MockIdentityProvider } from './mock-identity-provider';
import { NdidIdentityProvider } from './ndid-identity-provider';

export function getPaymentProvider(providerName: string = process.env.PAYMENT_PROVIDER || 'mock'): PaymentProvider {
  switch (providerName as PaymentProviderName) {
    case 'opn':
      return new OpnPaymentProvider();
    case 'mock':
    default:
      return new MockPaymentProvider();
  }
}

export function getIdentityProvider(providerName: string = process.env.IDENTITY_PROVIDER || 'mock'): IdentityProvider {
  switch (providerName as IdentityProviderName) {
    case 'ndid':
      return new NdidIdentityProvider();
    case 'mock':
    default:
      return new MockIdentityProvider();
  }
}
