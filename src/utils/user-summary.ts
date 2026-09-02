/**
 * The public-facing slice of a user shown on cards and detail screens:
 * name, avatar and reputation. Never includes contact details or the email.
 */
export interface UserSummary {
  id: string;
  full_name: string;
  avatar_url: string | null;
  home_city: string | null;
  rating_avg: number;
  rating_count: number;
  delivered_count: number;
}

export interface UserSummaryRow {
  id: string;
  full_name: string;
  avatar_url?: string | null;
  home_city?: string | null;
  rating_sum?: number | string | null;
  rating_count?: number | string | null;
  delivered_count?: number | string | null;
}

export function toUserSummary(row: UserSummaryRow): UserSummary {
  const count = Number(row.rating_count ?? 0);
  const sum = Number(row.rating_sum ?? 0);
  return {
    id: row.id,
    full_name: row.full_name,
    avatar_url: row.avatar_url ?? null,
    home_city: row.home_city ?? null,
    rating_avg: count > 0 ? Math.round((sum / count) * 10) / 10 : 0,
    rating_count: count,
    delivered_count: Number(row.delivered_count ?? 0),
  };
}

/** Columns to select from `users` when a summary is needed. */
export const USER_SUMMARY_COLUMNS = [
  'id',
  'full_name',
  'avatar_url',
  'home_city',
  'rating_sum',
  'rating_count',
  'delivered_count',
] as const;
