import { AwsClient } from 'aws4fetch';
import type { FileStore } from './types';

export interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicBaseUrl: string;
}

/**
 * Cloudflare R2 over its S3-compatible API, signed with SigV4 (aws4fetch — a
 * few KB, no aws-sdk). Objects are written public-read via the bucket's own
 * public access setting; `url()` points at `publicBaseUrl` (the r2.dev URL or a
 * custom domain).
 */
export class R2FileStore implements FileStore {
  readonly urlIsRelative = false;
  private readonly client: AwsClient;
  private readonly endpoint: string;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;

  constructor(cfg: R2Config) {
    this.client = new AwsClient({
      accessKeyId: cfg.accessKeyId,
      secretAccessKey: cfg.secretAccessKey,
      service: 's3',
      region: 'auto',
    });
    this.endpoint = `https://${cfg.accountId}.r2.cloudflarestorage.com`;
    this.bucket = cfg.bucket;
    this.publicBaseUrl = cfg.publicBaseUrl;
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    const res = await this.client.fetch(`${this.endpoint}/${this.bucket}/${key}`, {
      method: 'PUT',
      body,
      headers: { 'Content-Type': contentType },
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      throw new Error(`R2 upload failed (${res.status}): ${detail.slice(0, 200)}`);
    }
  }

  url(key: string): string {
    return `${this.publicBaseUrl}/${key}`;
  }
}
