type Tone = 'neutral' | 'positive' | 'warning' | 'negative';

export function StatusPill({ label, tone = 'neutral' }: { label: string; tone?: Tone }) {
  return <span className={`pill pill-${tone}`}>{label}</span>;
}
