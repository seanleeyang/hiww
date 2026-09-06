/**
 * Ephemeral "is typing" state for order chat. In-memory, not persisted —
 * losing it on a restart has zero real consequence (worst case: an
 * indicator that would have shown briefly doesn't), and it saves a DB write
 * on every keystroke-adjacent heartbeat. A single Render instance is all
 * this pilot runs, so no cross-instance sync is needed either.
 */

const TYPING_TTL_MS = 8000;

interface TypingEntry {
  userId: string;
  at: number;
}

// One entry per order is enough for a 2-participant conversation — if both
// happened to type at once, whichever pinged most recently wins, which is a
// fine simplification here.
const typingByOrder = new Map<string, TypingEntry>();

export function recordTyping(orderId: string, userId: string): void {
  typingByOrder.set(orderId, { userId, at: Date.now() });
}

export function isCounterpartyTyping(orderId: string, viewerId: string): boolean {
  const entry = typingByOrder.get(orderId);
  if (!entry || entry.userId === viewerId) return false;
  return Date.now() - entry.at < TYPING_TTL_MS;
}
