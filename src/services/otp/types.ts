export type OtpChannel = 'email' | 'phone';

/** Sends a one-time code over one channel. Never throws for a bad address —
 * delivery failures should not block registration; log and move on. */
export interface OtpSender {
  sendEmailOtp(email: string, code: string): Promise<void>;
  sendSmsOtp(phone: string, code: string): Promise<void>;
}
