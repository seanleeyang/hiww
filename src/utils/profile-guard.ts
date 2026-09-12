import { AppError } from '@/utils/helpers';

/** The contact/delivery fields a user must fill in before their first order. */
export interface ProfileCompletenessRow {
  phone?: string | null;
  address_street?: string | null;
  address_street2?: string | null;
  address_subdistrict?: string | null;
  address_district?: string | null;
  address_city?: string | null;
  address_postal_code?: string | null;
  address_country?: string | null;
}

function filled(value?: string | null): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function missingPhone(user: ProfileCompletenessRow): boolean {
  return !filled(user.phone);
}

function missingAddress(user: ProfileCompletenessRow): boolean {
  return (
    !filled(user.address_street) ||
    !filled(user.address_city) ||
    !filled(user.address_postal_code) ||
    !filled(user.address_country)
  );
}

export function isProfileComplete(user: ProfileCompletenessRow): boolean {
  return !missingPhone(user) && !missingAddress(user);
}

/**
 * Both sides of an order need a phone number and delivery address before it
 * exists — the traveler when they make an offer, the shopper when they
 * accept one. Throws the same error code either way so the client can show
 * one "complete your profile" prompt, but names only whichever of the two
 * is actually missing — telling someone to "add your phone number and
 * delivery address" when they'd already added their phone number reads as
 * the app not noticing what they just did. Returns the row (address fields
 * included) so a caller that needs it — e.g. resolving a "same as
 * registered address" delivery snapshot at accept-offer time — doesn't have
 * to query it again.
 */
export async function requireCompleteProfile(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: any,
  userId: string
): Promise<ProfileCompletenessRow> {
  const user = await db
    .selectFrom('users')
    .select([
      'phone',
      'address_street',
      'address_street2',
      'address_subdistrict',
      'address_district',
      'address_city',
      'address_postal_code',
      'address_country',
    ])
    .where('id', '=', userId)
    .executeTakeFirst();

  if (!user) {
    throw new AppError('PROFILE_INCOMPLETE', 403, 'profileGuard.incompletePhoneAndAddress');
  }
  const noPhone = missingPhone(user);
  const noAddress = missingAddress(user);
  if (noPhone && noAddress) {
    throw new AppError('PROFILE_INCOMPLETE', 403, 'profileGuard.incompletePhoneAndAddress');
  }
  if (noPhone) {
    throw new AppError('PROFILE_INCOMPLETE', 403, 'profileGuard.incompletePhone');
  }
  if (noAddress) {
    throw new AppError('PROFILE_INCOMPLETE', 403, 'profileGuard.incompleteAddress');
  }
  return user;
}
