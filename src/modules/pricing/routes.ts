import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '@/utils/helpers';
import { calculatePricing } from '@/services/pricing';

const previewQuerySchema = z.object({
  item_price: z.string().regex(/^\d+(\.\d{1,2})?$/),
});

/**
 * Lets the mobile app show the itemized price breakdown before an order
 * exists (accept-offer confirmation, make-offer screen) without
 * re-implementing `calculatePricing` in Dart. Purely informational — the
 * actual order is always priced fresh server-side at accept time from the
 * stored offer, regardless of what was last previewed here.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerPricingRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Querystring: { item_price?: string } }>(
    '/api/pricing/preview',
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async (request, reply) => {
      const parsed = previewQuerySchema.safeParse(request.query);
      if (!parsed.success) {
        throw new AppError('VALIDATION_ERROR', 400, 'pricing.invalidItemPrice');
      }

      reply.send({
        success: true,
        data: calculatePricing(parsed.data.item_price),
        code: 'PRICING_PREVIEW',
      });
    }
  );
}
