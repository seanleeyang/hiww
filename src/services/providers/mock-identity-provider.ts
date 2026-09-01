import { IdentityProvider, IdentityVerificationResult } from './types';

export class MockIdentityProvider implements IdentityProvider {
  readonly providerName = 'mock_identity_provider';

  async verify(userId: string, documentType: string, documentId: string): Promise<IdentityVerificationResult> {
    return {
      provider: this.providerName,
      status: 'verified',
      user_id: userId,
      document_type: documentType,
      document_id: documentId,
    };
  }
}
