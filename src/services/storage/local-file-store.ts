import { mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import type { FileStore } from './types';

/**
 * Writes to a directory on disk. The upload route registers `@fastify/static`
 * on `/uploads/` to serve them back.
 */
export class LocalFileStore implements FileStore {
  readonly urlIsRelative = true;
  private readonly root: string;

  constructor(uploadDir: string) {
    this.root = resolve(process.cwd(), uploadDir);
  }

  async ready(): Promise<string> {
    await mkdir(this.root, { recursive: true });
    return this.root;
  }

  async put(key: string, body: Buffer): Promise<void> {
    await writeFile(join(this.root, key), body);
  }

  url(key: string): string {
    return `/uploads/${key}`;
  }
}
