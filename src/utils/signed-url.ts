import crypto from 'crypto';
import { config } from '@/config/env';

// A distinct key derived from JWT_SECRET (not the raw secret itself) — reuses
// the one strong secret this app already requires instead of adding a second
// env var, while still keeping the two signing purposes cryptographically
// separate (a leak of one signing key doesn't imply the other).
const SIGNING_KEY = crypto.createHmac('sha256', config.jwtSecret).update('upload-url-signing').digest();

/**
 * Short-lived "coat check ticket" for one specific private file — see
 * src/modules/uploads/routes.ts. The authorization decision (is this caller
 * allowed to see this particular photo) is made once, at the moment a URL
 * containing one of these is handed out; the file-serving route itself just
 * checks the signature and expiry, with no further per-request DB lookup.
 */
export function signUploadKey(key: string, ttlSeconds: number): { exp: number; sig: string } {
  const exp = Date.now() + ttlSeconds * 1000;
  const sig = crypto.createHmac('sha256', SIGNING_KEY).update(`${key}.${exp}`).digest('hex');
  return { exp, sig };
}

export function verifySignedUploadKey(key: string, exp: string | undefined, sig: string | undefined): boolean {
  if (!exp || !sig) return false;
  const expNum = Number(exp);
  if (!Number.isFinite(expNum) || expNum < Date.now()) return false;

  const expected = crypto.createHmac('sha256', SIGNING_KEY).update(`${key}.${exp}`).digest('hex');
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Appends a signature to a stored `.../uploads/<key>` URL so it keeps working
 * for `ttlSeconds` and then stops — for handing a KYC document/selfie photo
 * to whoever was just found authorized to see it (an admin reviewing it, or
 * the account's own owner), without requiring every `<img>`/`Image.network`
 * that renders it to attach an auth header. `null`/empty in is `null` out,
 * so call sites can pass a possibly-unset photo URL straight through.
 */
export function signKycPhotoUrl(url: string | null | undefined, ttlSeconds = 15 * 60): string | null {
  if (!url) return null;
  const marker = '/uploads/';
  const idx = url.indexOf(marker);
  if (idx === -1) return url; // Not one of our upload URLs — nothing to sign.

  const key = url.slice(idx + marker.length);
  const { exp, sig } = signUploadKey(key, ttlSeconds);
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}exp=${exp}&sig=${sig}`;
}
