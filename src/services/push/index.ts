import { config } from '@/config/env';
import type { PushSender } from './types';
import { MockPushSender } from './mock-push-sender';
import { FirebasePushSender } from './firebase-push-sender';

export type { PushSender, PushMessage, PushSendResult } from './types';
export { MockPushSender } from './mock-push-sender';

let cached: PushSender | undefined;

/**
 * The configured push sender. `fcm` needs both PUSH_PROVIDER=fcm and a
 * FIREBASE_SERVICE_ACCOUNT_JSON; anything else (and the test run) gets the
 * mock.
 */
export function getPushSender(): PushSender {
  if (cached) return cached;
  cached =
    config.pushProvider === 'fcm' && config.firebaseServiceAccountJson
      ? new FirebasePushSender(config.firebaseServiceAccountJson)
      : new MockPushSender();
  return cached;
}

/** Test seam. */
export function __setPushSender(sender: PushSender | undefined): void {
  cached = sender;
}
