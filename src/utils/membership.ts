/**
 * Formats a user's raw `member_seq` into the membership number shown to
 * users and admins, e.g. `H00000123`. Purely a display format — the
 * underlying identity is still `users.id`; this exists so admins/support
 * have something short and speakable to reference an account by.
 */
export function membershipId(seq: number): string {
  return `H${String(seq).padStart(8, '0')}`;
}
