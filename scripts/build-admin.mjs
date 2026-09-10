// Build the admin console (admin-web/) and drop it where the backend serves
// it from — public/admin/, the same place the Dockerfile copies it at image
// build time. Run this before `npm run dev:e2e` if you want to click through
// the console locally, or before the admin-console e2e suite.
//
//   node scripts/build-admin.mjs
import { execSync } from 'node:child_process';
import { cpSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const adminWeb = join(root, 'admin-web');
const dest = join(root, 'public', 'admin');

if (!existsSync(join(adminWeb, 'node_modules'))) {
  console.error('[build:admin] admin-web/node_modules missing — run `npm ci` in admin-web/ first');
  process.exit(1);
}

execSync('npm run build', { cwd: adminWeb, stdio: 'inherit' });

if (existsSync(dest)) rmSync(dest, { recursive: true, force: true });
cpSync(join(adminWeb, 'dist'), dest, { recursive: true });
console.log('[build:admin] admin-web/dist -> public/admin');
