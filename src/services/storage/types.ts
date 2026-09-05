/**
 * Where uploaded images are kept. Kept behind an interface so the pilot can run
 * off local disk and production can use Cloudflare R2 without the upload route
 * caring which.
 */
export interface FileStore {
  /** Store `body` under `key` (a filename like `<id>.jpg`). */
  put(key: string, body: Buffer, contentType: string): Promise<void>;

  /**
   * Where the stored file is reachable. An absolute `https://…` URL for a
   * remote store, or a root-relative path (`/uploads/<key>`) for the local
   * store — the caller resolves a relative path against the request origin.
   */
  url(key: string): string;

  /** True when `url()` returns a relative path that needs an origin prefix. */
  readonly urlIsRelative: boolean;
}
