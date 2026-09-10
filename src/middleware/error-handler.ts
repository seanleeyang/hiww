import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { AppError } from '@/utils/helpers';
import { t } from '@/i18n/messages';
import type { ApiResponse } from '@/types/api';

export async function registerErrorHandler(app: FastifyInstance): Promise<void> {
  app.setErrorHandler(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (error: any, request: FastifyRequest, reply: FastifyReply): void => {
      const locale = request.locale ?? 'en';

      if (error instanceof AppError) {
        void reply.status(error.statusCode).send({
          success: false,
          error: error.localize(locale),
          code: error.code,
        } as ApiResponse<null>);
        return;
      }

      // Honour the status carried by framework/plugin errors (validation → 400,
      // rate limit → 429, etc). Only genuine 5xx and un-tagged errors are logged
      // and reported as an internal error.
      const statusCode = typeof error.statusCode === 'number' ? error.statusCode : 500;

      if (statusCode >= 500) {
        request.log.error(error);
        console.error('Unhandled error:', error);
      }

      void reply.status(statusCode).send({
        success: false,
        error:
          statusCode >= 500
            ? t(locale, 'common.internalServerError')
            : error.message || t(locale, 'common.requestFailed'),
        code: error.code || (statusCode >= 500 ? 'INTERNAL_ERROR' : 'REQUEST_ERROR'),
      } as ApiResponse<null>);
    }
  );
}
