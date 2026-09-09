import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { PushSender, PushMessage, PushSendResult } from './types';

/** Real Firebase Cloud Messaging sender. Needs a service account's full
 * JSON key (see `FIREBASE_SERVICE_ACCOUNT_JSON` in `.env.example` and
 * `mobile/lib/firebase_options.dart` for the matching client setup). */
export class FirebasePushSender implements PushSender {
  private readonly app: App;

  constructor(serviceAccountJson: string) {
    // Named (not default) so a second `new FirebasePushSender(...)` — e.g. in
    // a test that swaps the service account — doesn't collide with an
    // already-initialized default app elsewhere in the process.
    const existing = getApps().find((a) => a.name === 'hiww-push');
    this.app =
      existing ?? initializeApp({ credential: cert(JSON.parse(serviceAccountJson)) }, 'hiww-push');
  }

  async send(tokens: string[], message: PushMessage): Promise<PushSendResult> {
    if (!tokens.length) return { deadTokens: [] };

    const response = await getMessaging(this.app).sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data ?? {},
    });

    const deadTokens = response.responses
      .map((r, i) => (!r.success && isUnregistered(r.error?.code) ? tokens[i] : null))
      .filter((t): t is string => t !== null);

    return { deadTokens };
  }
}

function isUnregistered(code: string | undefined): boolean {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  );
}
