import crypto from 'crypto';
// Relative, not the `@/` alias — this module is also imported from
// migrations/047_encrypt_bank_account_numbers.ts, reached (via
// migrations/list.ts) by Jest's globalSetup through a loader that doesn't
// apply the alias's moduleNameMapper the way normal test files do.
import { config } from '../config/env';

// AES-256-GCM: authenticated encryption — decrypting also proves the stored
// value wasn't tampered with (a corrupted/edited ciphertext fails to
// decrypt at all, rather than silently producing garbage). DATA_ENCRYPTION_KEY
// is a separate secret from JWT_SECRET on purpose (see src/config/env.ts).
const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12; // GCM's recommended nonce size.
const KEY = crypto.createHash('sha256').update(config.dataEncryptionKey).digest(); // -> exactly 32 bytes for AES-256.

// Every ciphertext is tagged with this prefix so `decryptSecret` can tell an
// already-encrypted value apart from a legacy plaintext one written before
// this existed (or a test fixture that writes straight to the DB) — those
// pass through unchanged instead of failing to decrypt.
const PREFIX = 'enc:v1:';

/**
 * Encrypts a sensitive value (a bank account number) for storage. `null`/
 * empty in is `null` out, so call sites can pass a possibly-unset field
 * straight through without a separate guard.
 */
export function encryptSecret(plaintext: string | null | undefined): string | null {
  if (!plaintext) return null;

  const iv = crypto.randomBytes(IV_BYTES);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return `${PREFIX}${iv.toString('base64')}:${authTag.toString('base64')}:${ciphertext.toString('base64')}`;
}

/**
 * Reverses {@link encryptSecret}. A value with no recognized prefix is
 * assumed to be legacy plaintext (or already-decrypted) and returned as-is
 * — this is what lets old rows keep working right up until the backfill
 * migration (or the next write) encrypts them, instead of crashing.
 */
export function decryptSecret(stored: string | null | undefined): string | null {
  if (!stored) return null;
  if (!stored.startsWith(PREFIX)) return stored;

  const [ivB64, authTagB64, ciphertextB64] = stored.slice(PREFIX.length).split(':');
  if (!ivB64 || !authTagB64 || !ciphertextB64) return stored; // Malformed — fail open to the raw value rather than throw.

  const decipher = crypto.createDecipheriv(ALGORITHM, KEY, Buffer.from(ivB64, 'base64'));
  decipher.setAuthTag(Buffer.from(authTagB64, 'base64'));
  const plaintext = Buffer.concat([decipher.update(Buffer.from(ciphertextB64, 'base64')), decipher.final()]);
  return plaintext.toString('utf8');
}

/** True if a stored value is already in encrypted form — used by the
 * one-time backfill migration to skip rows it's already handled. */
export function isEncryptedSecret(stored: string | null | undefined): boolean {
  return typeof stored === 'string' && stored.startsWith(PREFIX);
}
