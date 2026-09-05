import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { FastifyInstance, FastifyRequest } from 'fastify';
import fastifyStatic from '@fastify/static';
import { config } from '@/config/env';
import { AppError, generateId } from '@/utils/helpers';
import { getFileStore } from '@/services/storage';

const EXT_BY_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/** Absolute origin for building file URLs — configured value, or the request's. */
function originFor(request: FastifyRequest): string {
  if (config.publicBaseUrl) return config.publicBaseUrl;
  const host = request.headers.host ?? `localhost:${config.port}`;
  return `${request.protocol}://${host}`;
}

export async function registerUploadRoutes(app: FastifyInstance): Promise<void> {
  const store = getFileStore();

  // Always serve `/uploads/*` from local disk — with the R2 backend nothing new
  // is written there, but any pre-existing local files keep working.
  const uploadRoot = resolve(process.cwd(), config.uploadDir);
  await mkdir(uploadRoot, { recursive: true });
  await app.register(fastifyStatic, {
    root: uploadRoot,
    prefix: '/uploads/',
    maxAge: '365d',
    immutable: true,
  });

  // Accept a single image and return its public URL. Auth is enforced by the
  // global guard; anyone signed in may upload.
  app.post(
    '/api/uploads',
    { config: { rateLimit: { max: config.uploadRateLimitMax, timeWindow: config.rateLimitWindow } } },
    async (request, reply) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      if (!(request as any).isMultipart()) {
        throw new AppError('VALIDATION_ERROR', 400, 'Send the image as multipart/form-data');
      }

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let file: any;
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        file = await (request as any).file({
          limits: { files: 1, fileSize: config.maxUploadBytes },
        });
      } catch {
        file = undefined;
      }

      if (!file) {
        throw new AppError('VALIDATION_ERROR', 400, 'Attach an image file in the "file" field');
      }

      const ext = EXT_BY_MIME[file.mimetype];
      if (!ext) {
        throw new AppError('VALIDATION_ERROR', 400, 'Only JPEG, PNG or WebP images are allowed');
      }

      let buffer: Buffer;
      try {
        buffer = await file.toBuffer();
      } catch {
        // @fastify/multipart throws once the stream passes fileSize.
        throw new AppError(
          'VALIDATION_ERROR',
          400,
          `Image is larger than ${Math.round(config.maxUploadBytes / (1024 * 1024))} MB`
        );
      }
      if (file.file.truncated) {
        throw new AppError(
          'VALIDATION_ERROR',
          400,
          `Image is larger than ${Math.round(config.maxUploadBytes / (1024 * 1024))} MB`
        );
      }

      const name = `${generateId()}.${ext}`;
      try {
        await store.put(name, buffer, file.mimetype);
      } catch (err) {
        request.log.error({ err }, 'upload store failed');
        throw new AppError('UPLOAD_FAILED', 502, 'Could not store the image. Try again.');
      }

      const stored = store.url(name);
      const url = store.urlIsRelative ? `${originFor(request)}${stored}` : stored;
      reply.status(201).send({ success: true, data: { url }, code: 'UPLOAD_CREATED' });
    }
  );
}
