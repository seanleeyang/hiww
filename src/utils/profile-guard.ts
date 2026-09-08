import { AppError } from '@/utils/helpers';

/** The contact/delivery fields a user must fill in before their first order. */
export interface ProfileCompletenessRow {
  phone?: string | null;
  address_street?: string | null;
  address_city?: string | null;
  address_postal_code?: string | null;
  address_country?: string | null;
}

function filled(value?: string | null): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

export function isProfileComplete(user: ProfileCompletenessRow): boolean {
  return (
    filled(user.phone) &&
    filled(user.address_street) &&
    filled(user.address_city) &&
    filled(user.address_postal_code) &&
    filled(user.address_country)
  );
}

/**
 * Both sides of an order need a phone number and delivery address before it
 * exists — the traveler when they make an offer, the shopper when they
 * accept one. Throws the same error either way so the client can show one
 * "complete your profile" prompt.
 */
export async function requireCompleteProfile(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: any,
  userId: string
): Promise<void> {
  const user = await db
    .selectFrom('users')
    .select(['phone', 'address_street', 'address_city', 'address_postal_code', 'address_country'])
    .where('id', '=', userId)
    .executeTakeFirst();

  if (!user || !isProfileComplete(user)) {
    throw new AppError('PROFILE_INCOMPLETE', 403, 'profileGuard.incomplete');
  }
}
