import { config } from '@/config/env';
import type { FileStore } from './types';
import { LocalFileStore } from './local-file-store';
import { R2FileStore } from './r2-file-store';

export type { FileStore } from './types';
export { LocalFileStore } from './local-file-store';

let cached: FileStore | undefined;

function r2Configured(): boolean {
  return Boolean(
    config.r2AccountId &&
      config.r2AccessKeyId &&
      config.r2SecretAccessKey &&
      config.r2Bucket &&
      config.r2PublicBaseUrl
  );
}

/**
 * The configured file store. `r2` needs `UPLOADS_BACKEND=r2` and all five R2_*
 * values; anything missing falls back to local disk (with a warning in prod so
 * a misconfigured deploy is noticed).
 */
export function getFileStore(): FileStore {
  if (cached) return cached;

  if (config.uploadsBackend === 'r2') {
    if (r2Configured()) {
      cached = new R2FileStore({
        accountId: config.r2AccountId,
        accessKeyId: config.r2AccessKeyId,
        secretAccessKey: config.r2SecretAccessKey,
        bucket: config.r2Bucket,
        publicBaseUrl: config.r2PublicBaseUrl,
      });
      return cached;
    }
    if (config.nodeEnv === 'production') {
      // eslint-disable-next-line no-console
      console.warn('[storage] UPLOADS_BACKEND=r2 but R2_* config is incomplete — falling back to local disk (ephemeral)');
    }
  }

  cached = new LocalFileStore(config.uploadDir);
  return cached;
}

/** Test seam. */
export function __setFileStore(store: FileStore | undefined): void {
  cached = store;
}
