import { test, expect, type APIRequestContext } from '@playwright/test';

// The officer persona through their real interface: sign in to the admin
// console, create an order via Developer tools, confirm its payment through
// the confirm dialog, and check the action landed in the audit log — plus a
// couple of queue pages render. Needs the API + built console on :3000
// (`npm run dev:e2e` from the repo root, which also seeds this admin).

const API = process.env.HIWW_API_BASE_URL || 'http://localhost:3000';
const ADMIN_EMAIL = 'it-admin@example.com';
const ADMIN_PASSWORD = 'AdminPass123';

async function adminToken(request: APIRequestContext): Promise<string> {
  const res = await request.post(`${API}/api/auth/login`, {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD },
  });
  expect(
    res.ok(),
    'admin login failed — start the API with `npm run dev:e2e` (it seeds this admin)',
  ).toBeTruthy();
  return (await res.json()).data.token as string;
}

test('officer signs in, confirms a payment, and sees it in the audit log', async ({
  page,
  request,
}) => {
  const token = await adminToken(request);

  // --- Sign in through the real login form. ---
  await page.goto('/admin/');
  await page.getByLabel('Email').fill(ADMIN_EMAIL);
  await page.getByLabel('Password').fill(ADMIN_PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // --- Developer tools → create a ready-to-work order. ---
  await page.getByRole('link', { name: 'Developer tools' }).click();
  await page.getByRole('button', { name: 'Create a test order' }).click();
  const orderLink = page.getByRole('link', { name: /open order/i });
  await expect(orderLink).toBeVisible({ timeout: 30_000 });
  await orderLink.click();

  // --- Order detail: awaiting payment → confirm it through the dialog. ---
  await expect(page.getByText('Awaiting payment')).toBeVisible();
  await page.getByRole('button', { name: 'Confirm payment' }).click();
  await page
    .getByRole('dialog', { name: 'Confirm payment' })
    .getByRole('button', { name: 'Confirm payment' })
    .click();

  // Timeline gains the "Payment confirmed" step and the status pill flips to "Paid".
  await expect(page.locator('.timeline')).toContainText('Payment confirmed');
  await expect(page.getByText('Paid', { exact: true })).toBeVisible();

  const orderId = new URL(page.url()).pathname.split('/').pop() as string;

  // --- Audit log reflects it. ---
  await page.getByRole('link', { name: 'Audit log' }).click();
  await page.getByLabel('Action').fill('payment.confirm');
  await expect(
    page.getByRole('row', { name: new RegExp(orderId.slice(0, 8)) }),
  ).toContainText('payment.confirm');

  // --- ID checks queue page renders (its /admin/reviews query works). ---
  await page.getByRole('link', { name: 'ID checks' }).click();
  await expect(page.getByRole('heading', { name: 'ID checks' })).toBeVisible();

  // --- Backend agrees. ---
  const res = await request.get(`${API}/api/orders/${orderId}`, {
    headers: { authorization: `Bearer ${token}` },
  });
  expect((await res.json()).data.status).toBe('confirmed');
});
