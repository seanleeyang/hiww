export function money(amount: string | number | null | undefined): string {
  if (amount === null || amount === undefined) return '—';
  const n = typeof amount === 'string' ? Number(amount) : amount;
  if (Number.isNaN(n)) return String(amount);
  return `฿${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function dateTime(value: string | null | undefined): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function relativeTime(value: string | null | undefined): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  const deltaMs = Date.now() - d.getTime();
  const abs = Math.abs(deltaMs);
  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;
  const suffix = deltaMs >= 0 ? 'ago' : 'from now';
  if (abs < minute) return 'just now';
  if (abs < hour) return `${Math.floor(abs / minute)}m ${suffix}`;
  if (abs < day) return `${Math.floor(abs / hour)}h ${suffix}`;
  return `${Math.floor(abs / day)}d ${suffix}`;
}
