import type { OtpSender } from './types';

/**
 * Logs the code instead of sending it. Used for every environment until a
 * real SMS/email provider is wired in (see `getOtpSender` in `./index.ts`).
 * The register/resend-otp routes also echo the code back as `debug_otp` in
 * the response while this is active, so local dev, tests and `scripts/
 * seed-demo.mjs` can complete verification without a real inbox or phone.
 */
export class MockOtpSender implements OtpSender {
  async sendEmailOtp(email: string, code: string): Promise<void> {
    // eslint-disable-next-line no-console
    console.log(`[otp:mock] email to ${email}: ${code}`);
  }

  async sendSmsOtp(phone: string, code: string): Promise<void> {
    // eslint-disable-next-line no-console
    console.log(`[otp:mock] SMS to ${phone}: ${code}`);
  }
}
