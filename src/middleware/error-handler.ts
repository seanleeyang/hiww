import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { AppError } from '@/utils/helpers';
import type { ApiResponse } from '@/types/api';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerErrorHandler(app: FastifyInstance): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.setErrorHandler((error: any, _request: FastifyRequest, reply: FastifyReply): void => {
    if (error instanceof AppError) {
      void reply.status(error.statusCode).send({
        success: false,
        error: error.message,
        code: error.code,
      } as ApiResponse<null>);
      return;
    }

    console.error('Unhandled error:', error);

    void reply.status(500).send({
      success: false,
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
    } as ApiResponse<null>);
  });
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function registerSuccessHandler(app: FastifyInstance): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.addHook('onSend', async (_request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    if (reply.statusCode >= 400) {
      return;
    }

    // Skip if already has success flag
    // This is a simplified version; in production you might want more sophisticated logic
    return;
  });
}
