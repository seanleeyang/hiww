import crypto from 'crypto';
import { promisify } from 'util';
import { config } from '@/config/env';

const JWT_SECRET = config.jwtSecret;

const SCRYPT_KEYLEN = 64;
const SCRYPT_SALT_BYTES = 16;

// The sync variant (`scryptSync`) runs on Node's single main thread and fully
// blocks the event loop for its entire duration — with one Node process and
// no clustering, a handful of *concurrent* login/register calls would stall
// every other in-flight request app-wide. The async variant offloads the
// actual scrypt computation to libuv's threadpool instead.
const scryptAsync = promisify(crypto.scrypt) as (
  password: crypto.BinaryLike,
  salt: crypto.BinaryLike,
  keylen: number
) => Promise<Buffer>;

function encodeBase64Url(value: string): string {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function decodeBase64Url(value: string): string {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  const normalized = padded + '='.repeat((4 - (padded.length % 4)) % 4);
  return Buffer.from(normalized, 'base64').toString('utf8');
}

function constantTimeEquals(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Hash a password with scrypt and a per-user random salt.
 *
 * Format: `scrypt$<saltHex>$<hashHex>`. scrypt is deliberately slow and
 * memory-hard, so a leaked hash cannot be brute-forced at speed and two users
 * with the same password get different hashes.
 */
export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.randomBytes(SCRYPT_SALT_BYTES);
  const hash = await scryptAsync(password, salt, SCRYPT_KEYLEN);
  return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}

/**
 * Verify a plaintext password against a stored `scrypt$salt$hash` string.
 * Returns false for any malformed or legacy-format hash.
 */
export async function verifyPassword(password: string, stored: string | null | undefined): Promise<boolean> {
  if (!stored) {
    return false;
  }

  const parts = stored.split('$');
  if (parts.length !== 3 || parts[0] !== 'scrypt') {
    return false;
  }

  const salt = Buffer.from(parts[1], 'hex');
  const expected = Buffer.from(parts[2], 'hex');
  if (salt.length === 0 || expected.length === 0) {
    return false;
  }

  const actual = await scryptAsync(password, salt, expected.length);
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

export function signToken(payload: { userId: string; email: string; exp: number; tokenVersion: number }): string {
  const header = encodeBase64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = encodeBase64Url(JSON.stringify(payload));
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${header}.${body}`)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');

  return `${header}.${body}.${signature}`;
}

export function verifyToken(token: string): { userId: string; email: string; exp: number; tokenVersion: number } {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid token format');
  }

  const [header, body, signature] = parts;
  const expectedSignature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${header}.${body}`)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');

  if (!constantTimeEquals(signature, expectedSignature)) {
    throw new Error('Invalid token signature');
  }

  const payload = JSON.parse(decodeBase64Url(body));

  if (typeof payload.exp !== 'number' || payload.exp < Date.now()) {
    throw new Error('Token expired');
  }

  return payload;
}
