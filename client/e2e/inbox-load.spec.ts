import { test, expect } from '@playwright/test';

const BASE_URL =
  process.env.ALFRED_BASE_URL ?? 'https://alfred-im.github.io/XmppTest/';

async function enableFlutterAccessibility(page: import('@playwright/test').Page) {
  const a11y = page.getByRole('button', { name: 'Enable accessibility' });
  if (await a11y.isVisible().catch(() => false)) {
    await a11y.click({ force: true });
    await page.waitForTimeout(500);
  }
}

/**
 * Inbox deve comparire senza interazione (digitare nella ricerca non deve
 * essere necessario per uscire dalla rotella).
 */
test('lista conversazioni si carica senza digitare nella ricerca', async ({
  page,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const username =
    process.env.ALFRED_TEST_USERNAME ??
    `e2e${Date.now().toString().slice(-8)}`;
  const password = process.env.ALFRED_TEST_PASSWORD ?? 'E2eTestPass123!';

  await page.goto(BASE_URL, {
    waitUntil: 'networkidle',
    timeout: 90_000,
  });
  await enableFlutterAccessibility(page);

  const registerLink = page.getByText('Non hai un account? Registrati');
  const loginHeading = page.getByText('Accedi ad Alfred');

  if (await registerLink.isVisible().catch(() => false)) {
    await registerLink.click();
    await page.getByLabel('Username').fill(username);
    await page.getByLabel('Nome visualizzato').fill('E2E User');
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Registrati' }).click();
  } else if (await loginHeading.isVisible().catch(() => false)) {
    await page.getByLabel('Username').fill(username);
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Accedi' }).click();
  }

  await expect(page.getByText('Alfred', { exact: true })).toBeVisible({
    timeout: 45_000,
  });

  await expect(
    page.getByText(/Nessuna conversazione|Cerca conversazione/),
  ).toBeVisible({ timeout: 45_000 });

  await page.waitForTimeout(3_000);
  await expect(
    page.getByText(/Nessuna conversazione|Cerca conversazione/),
  ).toBeVisible();

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
