import { test, expect } from '@playwright/test';

const BASE_URL =
  process.env.ALFRED_BASE_URL ?? 'https://alfred-im.github.io/XmppTest/';

async function enableFlutterAccessibility(page: import('@playwright/test').Page) {
  const enabled = await page.evaluate(() => {
    const btn = document.querySelector(
      '[aria-label="Enable accessibility"]',
    ) as HTMLElement | null;
    if (!btn) return false;
    btn.click();
    return true;
  });
  if (enabled) {
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
  const email =
    process.env.ALFRED_TEST_EMAIL ??
    `${username}@example.com`;
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
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Username').fill(username);
    await page.getByLabel('Nome visualizzato').fill('E2E User');
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Registrati' }).click();
  } else if (await loginHeading.isVisible().catch(() => false)) {
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Accedi' }).click();
  }

  await expect(page.getByText('Alfred', { exact: true })).toBeVisible({
    timeout: 45_000,
  });

  await expect(
    page.getByText(/Nessun messaggio|Cerca messaggi/),
  ).toBeVisible({ timeout: 45_000 });

  await page.waitForTimeout(3_000);
  await expect(
    page.getByText(/Nessun messaggio|Cerca messaggi/),
  ).toBeVisible();

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
