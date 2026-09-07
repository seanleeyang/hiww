export type { OtpSender, OtpChannel } from './types';
export { getOtpSender, isMockOtp, __setOtpSender } from './provider';
export { issueOtp, verifyOtp } from './service';
