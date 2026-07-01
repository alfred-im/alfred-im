import { test, expect } from '@playwright/test';

import {
  enableFlutterAccessibility,
  readSavedAccountsManifest,
} from './helpers/flutter-a11y';

/**
 * Flusso utente (mobile, Alpha):
 * 1. pulisci dati → login account 1
 * 2. aggiungi account 2 → compaiono 2 account (sezione «Altri account»)
 * 3. F5 → devono restare 2 account (se il 2° sparisce, «Altri account» non c’è)
 *
 * Account via env ALFRED_ACCOUNT{1,2}_{EMAIL,PASSWORD}
 * Default: alfredagent1/2 (password note). Per test1/test2 imposta email/password.
 */
const BASE_URL =
  process.env.ALFRED_BASE_URL ?? 'https://alfred-im.github.io/XmppTest/';

const ACCOUNT1 = {
  email:
    process.env.ALFRED_ACCOUNT1_EMAIL ??
    'agadriel.sexpositive+alfredagent1@gmail.com',
  password: process.env.ALFRED_ACCOUNT1_PASSWORD ?? 'AlfredAgentDbg1!',
};

const ACCOUNT2 = {
  email:
    process.env.ALFRED_ACCOUNT2_EMAIL ??
    'agadriel.sexpositive+alfredagent2@gmail.com',
  password: process.env.ALFRED_ACCOUNT2_PASSWORD ?? 'AlfredAgentDbg2!',
};

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(300_000);

async function openAccountDrawer(page: import('@playwright/test').Page) {
  await page.locator('flt-semantics[role="button"]').first().click({ timeout: 20_000 });
  await page.waitForTimeout(500);
}

async function clickAggiungiAccount(page: import('@playwright/test').Page) {
  await openAccountDrawer(page);
  await page.getByText('Aggiungi account').click();
}

async function loginInAuthForm(
  page: import('@playwright/test').Page,
  email: string,
  password: string,
) {
  const emailField = page.getByRole('textbox', { name: 'Email' });
  await emailField.click();
  await emailField.fill(email);
  await page.getByLabel('Password', { exact: true }).click();
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Accedi' }).click();
  await page.waitForFunction(
    () => {
      const raw = localStorage.getItem('flutter.alfred_saved_accounts');
      return raw != null && raw.length > 20;
    },
    { timeout: 120_000 },
  );
  await page.waitForTimeout(2000);
  await enableFlutterAccessibility(page);
}

async function expectLoggedInShell(page: import('@playwright/test').Page) {
  await expect(page.getByText('Nessun account aperto')).not.toBeVisible({
    timeout: 90_000,
  });
}

/** Con 2+ account in RAM la sidebar mobile mostra «Altri account». */
async function expectMultiAccountList(
  page: import('@playwright/test').Page,
  visible: boolean,
) {
  await openAccountDrawer(page);
  const section = page.getByText('Altri account');
  if (visible) {
    await expect(section).toBeVisible({ timeout: 30_000 });
  } else {
    await expect(section).not.toBeVisible({ timeout: 10_000 });
  }
  await page.keyboard.press('Escape');
}

function expectManifestCount(
  manifest: { userId: string; refreshToken: string }[] | null,
  count: number,
) {
  expect(manifest, 'manifest assente').not.toBeNull();
  expect(manifest!.length, `manifest: ${JSON.stringify(manifest)}`).toBe(count);
  if (count >= 2) {
    const tokens = manifest!.map((e) => e.refreshToken);
    expect(
      new Set(tokens).size,
      `refreshToken duplicati: ${JSON.stringify(manifest)}`,
    ).toBe(count);
  }
}

test('multi-account mobile: dopo F5 restano 2 account in lista (flusso utente)', async ({
  page,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 90_000 });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 90_000 });
  await page.waitForTimeout(8000);
  await enableFlutterAccessibility(page);

  // Account 1
  await expect(page.getByRole('textbox', { name: 'Email' })).toBeVisible({
    timeout: 60_000,
  });
  await loginInAuthForm(page, ACCOUNT1.email, ACCOUNT1.password);
  await expectLoggedInShell(page);
  expectManifestCount(await readSavedAccountsManifest(page), 1);
  await expectMultiAccountList(page, false);

  // Account 2
  await clickAggiungiAccount(page);
  await expect(page.getByRole('textbox', { name: 'Email' })).toBeVisible({
    timeout: 15_000,
  });
  await loginInAuthForm(page, ACCOUNT2.email, ACCOUNT2.password);
  await expectLoggedInShell(page);
  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  // F5 — il bug utente: resta solo il primo, «Altri account» sparisce
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 90_000 });
  await page.waitForTimeout(12_000);
  await enableFlutterAccessibility(page);
  await expectLoggedInShell(page);

  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
