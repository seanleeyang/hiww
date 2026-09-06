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
});

export type CreateRequestInput = z.infer<typeof createRequestSchema>;

export const purchaseProofSchema = z.object({
  image_url: z.string().trim().url().max(2048),
  note: z.string().trim().max(500).optional(),
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

export const profileUpdateSchema = z
  .object({
    full_name: z.string().trim().min(2).max(120).optional(),
    home_city: z.string().trim().max(120).nullable().optional(),
    avatar_url: z.string().trim().url().max(2048).nullable().optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'No fields to update',
  });
