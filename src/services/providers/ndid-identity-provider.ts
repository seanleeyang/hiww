import { IdentityProvider, IdentityVerificationResult } from './types';

export class NdidIdentityProvider implements IdentityProvider {
  readonly providerName = 'ndid_identity_provider';

  async verify(userId: string, documentType: string, documentId: string): Promise<IdentityVerificationResult> {
    // TODO: replace with real NDID integration.
    // Example pattern:
    // const response = await fetch(`${process.env.NDID_API_URL}/verify`, {
    //   method: 'POST',
    //   headers: {
    //     Authorization: `Bearer ${process.env.NDID_API_KEY}`,
    //     'Content-Type': 'application/json',
    //   },
    //   body: JSON.stringify({
    //     user_id: userId,
    //     document_type: documentType,
    //     document_id: documentId,
    //   }),
    // });

    return {
      provider: this.providerName,
      status: 'verified',
      user_id: userId,
      document_type: documentType,
      document_id: documentId,
    };
  }
}
