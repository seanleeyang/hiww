import { z } from 'zod';

export const createTripSchema = z.object({
  departure_country: z.string().min(1),
  arrival_country: z.string().min(1),
  departure_date: z.string().datetime(),
  return_date: z.string().datetime(),
  max_weight_kg: z.number().positive(),
  max_items: z.number().positive(),
});

export type CreateTripInput = z.infer<typeof createTripSchema>;

export const createRequestSchema = z.object({
  item_description: z.string().min(10),
  source_country: z.string().min(1),
  category: z.string().min(1),
  estimated_weight_kg: z.number().positive(),
  budget: z.string().regex(/^\d+(\.\d{2})?$/),
});

export type CreateRequestInput = z.infer<typeof createRequestSchema>;

export const createOrderSchema = z.object({
  trip_id: z.string().uuid().optional(),
  request_id: z.string().uuid().optional(),
  item_description: z.string().min(1),
  quantity: z.number().positive().int(),
  unit_price: z.string().regex(/^\d+(\.\d{2})?$/),
});

export type CreateOrderInput = z.infer<typeof createOrderSchema>;
