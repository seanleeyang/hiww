import { z } from 'zod';

const optionalText = (max = 200): z.ZodOptional<z.ZodString> =>
  z.string().trim().min(1).max(max).optional();
const optionalUrl = z.string().trim().url().max(2048).optional();

export const createTripSchema = z.object({
  departure_country: z.string().min(1),
  arrival_country: z.string().min(1),
  departure_date: z.string().datetime(),
  return_date: z.string().datetime(),
  max_weight_kg: z.number().positive(),
  max_items: z.number().positive(),
  // Presentation fields (optional; migration 007).
  title: optionalText(120),
  departure_city: optionalText(120),
  arrival_city: optionalText(120),
  note: optionalText(1000),
  cover_image_url: optionalUrl,
});

export type CreateTripInput = z.infer<typeof createTripSchema>;

// Route (departure/arrival country) is intentionally not editable — it's
// the trip's identity; changing it would silently invalidate whatever a
// shopper matched against. Everything else about the trip can be corrected.
export const updateTripSchema = z.object({
  departure_date: z.string().datetime().optional(),
  return_date: z.string().datetime().optional(),
  max_weight_kg: z.number().positive().optional(),
  max_items: z.number().positive().optional(),
  title: optionalText(120),
  departure_city: optionalText(120),
  arrival_city: optionalText(120),
  note: optionalText(1000),
  cover_image_url: optionalUrl,
});

export type UpdateTripInput = z.infer<typeof updateTripSchema>;

export const createRequestSchema = z.object({
  item_description: z.string().min(10),
  source_country: z.string().min(1),
  category: z.string().min(1),
  estimated_weight_kg: z.number().positive(),
  budget: z.string().regex(/^\d+(\.\d{2})?$/),
  quantity: z.number().int().min(1).max(99).optional(),
  // Presentation fields (optional; migration 007).
  title: optionalText(120),
  source_city: optionalText(120),
  need_by: z.string().datetime().optional(),
  image_url: optionalUrl,
  // Delivery destination (migration 027) — required at create time, distinct
  // from source_country/source_city (where to buy the item).
  destination_country: z.string().min(1),
  destination_city: optionalText(120),
  product_url: optionalUrl,
  // Set via "Request from this trip" — see src/modules/requests/routes.ts.
  target_trip_id: z.string().uuid().optional(),
});

export type CreateRequestInput = z.infer<typeof createRequestSchema>;

// Source country is intentionally not editable, same reasoning as trips.
export const updateRequestSchema = z.object({
  item_description: z.string().min(10).optional(),
  category: z.string().min(1).optional(),
  estimated_weight_kg: z.number().positive().optional(),
  budget: z
    .string()
    .regex(/^\d+(\.\d{2})?$/)
    .optional(),
  quantity: z.number().int().min(1).max(99).optional(),
  title: optionalText(120),
  source_city: optionalText(120),
  need_by: z.string().datetime().optional(),
  image_url: optionalUrl,
});

export type UpdateRequestInput = z.infer<typeof updateRequestSchema>;

export const purchaseProofSchema = z.object({
  image_url: z.string().trim().url().max(2048),
  item_photo_url: z.string().trim().url().max(2048).optional(),
  note: z.string().trim().max(500).optional(),
});

export const shippingProofSchema = z.object({
  image_url: z.string().trim().url().max(2048),
});

/** `image_url` is optional here so an idempotent no-op retry (already
 * `delivered`) doesn't need one — the route itself requires it before
 * actually transitioning `in_transit` -> `delivered`. */
export const releaseSchema = z.object({
  note: z.string().trim().max(500).optional(),
  image_url: z.string().trim().url().max(2048).optional(),
});

export const createOrderSchema = z.object({
  trip_id: z.string().uuid().optional(),
  request_id: z.string().uuid().optional(),
  item_description: z.string().min(1),
  quantity: z.number().positive().int(),
  unit_price: z.string().regex(/^\d+(\.\d{2})?$/),
});

export type CreateOrderInput = z.infer<typeof createOrderSchema>;

export const reviewSchema = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().max(1000).optional(),
});

export const messageSchema = z
  .object({
    body: z.string().trim().max(2000).optional(),
    image_url: z.string().trim().url().max(2048).optional(),
  })
  .refine((data) => Boolean(data.body) || Boolean(data.image_url), {
    message: 'Provide a message or a photo',
  });

const optionalContactText = (max: number): z.ZodOptional<z.ZodNullable<z.ZodString>> =>
  z.string().trim().max(max).nullable().optional();

const PHONE_REGEX = /^\+?[0-9 ()-]{6,20}$/;

/** Required phone, for registration — validated the same way as the
 * optional one in `profileUpdateSchema` below. */
export const phoneSchema = z.string().trim().regex(PHONE_REGEX, 'Enter a valid phone number');

/**
 * Password policy for anywhere a password is being *set* (register, reset,
 * change) — never applied to login, since existing accounts may predate
 * this policy or have a password that no longer satisfies it. Minimum 8 /
 * maximum 128 (long passphrases are fine — length matters more than an
 * arbitrary short cap), and must mix letters with digits; special
 * characters are allowed but never required. This mirrors the common
 * baseline most consumer sites still enforce, even though the newest NIST
 * 800-63B guidance (Rev. 4, 2025) has moved away from mandating character-
 * mix rules in favor of length + breach-list checks — no breach-list
 * infrastructure exists here, so a composition floor is the practical
 * stand-in.
 */
export const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128, 'Password must be at most 128 characters')
  .refine((v) => /[a-zA-Z]/.test(v), 'Password must contain at least one letter')
  .refine((v) => /[0-9]/.test(v), 'Password must contain at least one number');

export const profileUpdateSchema = z
  .object({
    full_name: z.string().trim().min(2).max(120).optional(),
    home_city: z.string().trim().max(120).nullable().optional(),
    avatar_url: z.string().trim().url().max(2048).nullable().optional(),
    phone: phoneSchema.nullable().optional(),
    address_street: optionalContactText(200),
    address_city: optionalContactText(120),
    address_postal_code: optionalContactText(20),
    address_country: optionalContactText(120),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'No fields to update',
  });
