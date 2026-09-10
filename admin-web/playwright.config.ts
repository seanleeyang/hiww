import { defineConfig, devices } from '@playwright/test';

// Drives the real admin console (served by the backend at /admin/) against a
// live API — the officer-persona twin of mobile/integration_test/app_flow_test.dart.
//
//   npm run dev:e2e          # from the repo root — API + built console on :3000
//   cd admin-web && npm run e2e
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  reporter: process.env.CI ? [['list'], ['github']] : 'list',
  use: {
    baseURL: process.env.ADMIN_E2E_BASE_URL || 'http://localhost:3000/admin/',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
