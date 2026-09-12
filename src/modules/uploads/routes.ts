import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { FastifyInstance, FastifyRequest } from 'fastify';
import fastifyStatic from '@fastify/static';
import { config } from '@/config/env';
import { AppError, generateId } from '@/utils/helpers';
import { getFileStore } from '@/services/storage';
import { verifySignedUploadKey } from '@/utils/signed-url';

const EXT_BY_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

// Every key is `generateId() + '.' + ext` — a UUID plus one of the three
// extensions above. Validated up front both as basic path-traversal hygiene
// and because it's what makes a plain SQL `LIKE` below safe: nothing in this
// shape can ever contain a `%` or `_` wildcard.
const KEY_PATTERN = /^[0-9a-f-]+\.(jpg|png|webp)$/;

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
  // `wildcard: false` stops this from auto-registering its own catch-all
  // route — `reply.sendFile()` stays available, but every request comes
  // through the handler below instead, so a KYC photo can be told apart
  // from an ordinary public one before anything gets served.
  await app.register(fastifyStatic, {
    root: uploadRoot,
    prefix: '/uploads/',
    maxAge: '365d',
    immutable: true,
    wildcard: false,
  });

  // Avatars, trip covers, and want photos are still served openly here —
  // those are meant to be publicly visible (a guest browsing the feed has
  // no token at all). A KYC document/selfie photo, an order's proof photos,
  // or a chat image all require the signature that the one or two places
  // each of those is ever returned already stamps onto it (see
  // src/utils/signed-url.ts and its call sites).
  app.get<{ Params: { key: string }; Querystring: { exp?: string; sig?: string } }>(
    '/uploads/:key',
    async (request, reply) => {
      const { key } = request.params;
      if (!KEY_PATTERN.test(key)) {
        throw new AppError('NOT_FOUND', 404, 'common.fileNotFound');
      }

      const suffix = `%/uploads/${key}`;
      const [kycOwner, orderMatch, messageMatch] = await Promise.all([
        request.db
          .selectFrom('users')
          .select('id')
          .where((eb: any) =>
            eb.or([eb('kyc_document_photo_url', 'like', suffix), eb('kyc_selfie_photo_url', 'like', suffix)])
          )
          .executeTakeFirst(),
        request.db
          .selectFrom('orders')
          .select('id')
          .where((eb: any) =>
            eb.or([
              eb('purchase_proof_url', 'like', suffix),
              eb('item_photo_url', 'like', suffix),
              eb('shipping_proof_url', 'like', suffix),
              eb('delivery_proof_url', 'like', suffix),
            ])
          )
          .executeTakeFirst(),
        request.db.selectFrom('messages').select('id').where('image_url', 'like', suffix).executeTakeFirst(),
      ]);

      if (kycOwner || orderMatch || messageMatch) {
        if (!verifySignedUploadKey(key, request.query.exp, request.query.sig)) {
          throw new AppError('FORBIDDEN', 403, 'uploads.signatureRequired');
        }
      }

      return reply.sendFile(key);
    }
  );

  // Accept a single image and return its public URL. Auth is enforced by the
  // global guard; anyone signed in may upload.
  app.post(
    '/api/uploads',
    { config: { rateLimit: { max: config.uploadRateLimitMax, timeWindow: config.rateLimitWindow } } },
    async (request, reply) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      if (!(request as any).isMultipart()) {
        throw new AppError('VALIDATION_ERROR', 400, 'uploads.multipartRequired');
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
        throw new AppError('VALIDATION_ERROR', 400, 'uploads.fileRequired');
      }

      const ext = EXT_BY_MIME[file.mimetype];
      if (!ext) {
        throw new AppError('VALIDATION_ERROR', 400, 'uploads.invalidFormat');
      }

      let buffer: Buffer;
      try {
        buffer = await file.toBuffer();
      } catch {
        // @fastify/multipart throws once the stream passes fileSize.
        throw new AppError('VALIDATION_ERROR', 400, 'uploads.tooLarge', {
          maxMb: Math.round(config.maxUploadBytes / (1024 * 1024)),
        });
      }
      if (file.file.truncated) {
        throw new AppError('VALIDATION_ERROR', 400, 'uploads.tooLarge', {
          maxMb: Math.round(config.maxUploadBytes / (1024 * 1024)),
        });
      }

      const name = `${generateId()}.${ext}`;
      try {
        await store.put(name, buffer, file.mimetype);
      } catch (err) {
        request.log.error({ err }, 'upload store failed');
        throw new AppError('UPLOAD_FAILED', 502, 'uploads.storeFailed');
      }

      const stored = store.url(name);
      const url = store.urlIsRelative ? `${originFor(request)}${stored}` : stored;
      reply.status(201).send({ success: true, data: { url }, code: 'UPLOAD_CREATED' });
    }
  );
}
