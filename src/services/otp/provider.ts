import { config } from '@/config/env';
import type { OtpSender } from './types';
import { MockOtpSender } from './mock-sender';

let cached: OtpSender | undefined;

/**
 * The configured OTP sender. No real provider is implemented yet — every
 * value of OTP_PROVIDER gets the mock today; this is the seam a real one
 * (e.g. Twilio for SMS, any transactional-email API) plugs into later,
 * mirroring `getReceiptAnalyzer`/`getChatModerationAnalyzer`.
 */
export function getOtpSender(): OtpSender {
  if (cached) return cached;
  cached = new MockOtpSender();
  return cached;
}

/** True while codes are logged rather than actually delivered — callers use
 * this to decide whether to echo the code back in an API response. */
export function isMockOtp(): boolean {
  return config.otpProvider !== 'twilio' && config.otpProvider !== 'real';
}

/** Test seam. */
export function __setOtpSender(sender: OtpSender | undefined): void {
  cached = sender;
}
