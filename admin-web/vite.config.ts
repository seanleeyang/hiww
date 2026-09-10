/// <reference types="vitest/config" />
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// The built app is served under /admin/* by the Fastify backend
// (see src/app.ts) — base must match so asset URLs resolve correctly.
export default defineConfig({
  base: '/admin/',
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:3000',
    },
  },
  build: {
    rollupOptions: {
      output: {
        // React/Router/Query change far less often than the app's own pages
        // — splitting them into their own chunk means a redeploy only
        // forces a re-download of the (much smaller) app code, not this too.
        manualChunks(id) {
          if (id.includes('node_modules') && /\/(react|react-dom|react-router-dom|@tanstack)\//.test(id)) {
            return 'vendor';
          }
        },
      },
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
  },
});
