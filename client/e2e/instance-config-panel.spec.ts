// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * E2E — pannello configurazione server (owner): tutti i campi del form fisso.
 *
 * Gate: `bash scripts/test.sh e2e-nav-local`
 */
import { test, expect } from '@playwright/test';

import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import {
  expectInstanceBootstrapViaRpc,
  expectInstanceConfigInDb,
  promoteProfileToOwner,
  type InstanceConfigExpectation,
} from './helpers/instance-config';
import { createLocalConfirmedUser } from './helpers/local-auth';
import {
  setupTwoLocalAccounts,
} from './helpers/local-multi-account';
import {
  BASE_URL,
  clearAppData,
  fillFlutterTextField,
  loginInAuthForm,
  switchToAccountByDisplayName,
  waitForLoggedInShell,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(120_000);

const FIELD_LABELS = {
  displayName: 'Nome visualizzato',
  imServerId: 'ID server IM',
  logoUrl: 'URL logo',
  themeColor: 'Colore tema',
  privacyUrl: 'Privacy',
  termsUrl: 'Termini',
  supportUrl: 'Supporto',
} as const;

test.beforeAll(() => {
  const url = process.env.SUPABASE_URL ?? '';
  test.skip(
    !url.includes('localhost') && !url.includes('127.0.0.1'),
    'richiede stack locale',
  );
});

async function expectConfigButtonVisible(
  page: import('@playwright/test').Page,
  visible: boolean,
) {
  const configButton = page.getByRole('button', {
    name: 'Configurazione server',
    exact: true,
  });
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        return configButton.isVisible().catch(() => false);
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [300, 500, 800] },
    )
    .toBe(visible);
}

async function openInstanceConfigScreen(page: import('@playwright/test').Page) {
  await expectConfigButtonVisible(page, true);
  await page.getByRole('button', {
    name: 'Configurazione server',
    exact: true,
  }).click();
  await expect(
    page.getByRole('button', { name: 'Salva configurazione', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}

async function fillInstanceConfigForm(
  page: import('@playwright/test').Page,
  values: InstanceConfigExpectation,
) {
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.displayName, exact: true }),
    values.displayName,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.imServerId, exact: true }),
    values.imServerId,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.logoUrl, exact: true }),
    values.logoUrl,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.themeColor, exact: true }),
    values.themeColor,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.privacyUrl, exact: true }),
    values.privacyUrl,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.termsUrl, exact: true }),
    values.termsUrl,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.supportUrl, exact: true }),
    values.supportUrl,
  );
}

async function expectInstanceConfigScreenLoaded(
  page: import('@playwright/test').Page,
  displayName: string,
) {
  await expect(
    page.getByRole('heading', {
      name: new RegExp(`Configurazione ${displayName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`),
    }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}

test('owner: tutti i campi configurazione server salvano e persistono', async ({
  page,
}) => {
  const stamp = Date.now();
  const owner = await createLocalConfirmedUser(`own${stamp}`);
  promoteProfileToOwner(owner.userId);

  const values: InstanceConfigExpectation = {
    displayName: `E2E Owner ${stamp}`,
    imServerId: `e2e-${stamp}.alfred.im`,
    logoUrl: `https://example.com/e2e/logo-${stamp}.png`,
    themeColor: '#AABBCC',
    privacyUrl: `https://example.com/e2e/privacy-${stamp}`,
    termsUrl: `https://example.com/e2e/terms-${stamp}`,
    supportUrl: `https://example.com/e2e/support-${stamp}`,
  };

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await clearAppData(page);
  await loginInAuthForm(page, owner.email, owner.password);
  await waitForLoggedInShell(page);

  await enableFlutterAccessibility(page);
  await openInstanceConfigScreen(page);
  await fillInstanceConfigForm(page, values);

  await page
    .getByRole('button', { name: 'Salva configurazione', exact: true })
    .click();
  await expect(
    page.getByText('Configurazione salvata', { exact: true }).first(),
  ).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });

  await expectInstanceConfigInDb(values);
  await expectInstanceBootstrapViaRpc(owner.email, owner.password, values);

  await page.getByRole('button', { name: 'Back' }).click();
  await expect(
    page.getByRole('button', { name: 'Nuovo messaggio' }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });

  await openInstanceConfigScreen(page);
  await expectInstanceConfigScreenLoaded(page, values.displayName);
  await expectInstanceBootstrapViaRpc(owner.email, owner.password, values);
});

test('non-owner: pulsante Configurazione server assente', async ({ page }) => {
  const stamp = Date.now();
  const user = await createLocalConfirmedUser(`usr${stamp}`);

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await clearAppData(page);
  await loginInAuthForm(page, user.email, user.password);
  await waitForLoggedInShell(page);

  await enableFlutterAccessibility(page);
  await expectConfigButtonVisible(page, false);
});

test('multi-account: salvataggio solo con owner in focus (no owner required)', async ({
  page,
}) => {
  const stamp = Date.now();
  const owner = await createLocalConfirmedUser(`own2${stamp}`);
  const user = await createLocalConfirmedUser(`usr2${stamp}`);
  promoteProfileToOwner(owner.userId);

  const values: InstanceConfigExpectation = {
    displayName: `E2E Owner focus ${stamp}`,
    imServerId: `e2e-focus-${stamp}.alfred.im`,
    logoUrl: `https://example.com/e2e/logo-focus-${stamp}.png`,
    themeColor: '#112233',
    privacyUrl: `https://example.com/e2e/privacy-focus-${stamp}`,
    termsUrl: `https://example.com/e2e/terms-focus-${stamp}`,
    supportUrl: `https://example.com/e2e/support-focus-${stamp}`,
  };

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });

  const { account1, account2 } = await setupTwoLocalAccounts(page, owner, user);

  await enableFlutterAccessibility(page);

  // Dopo il secondo login il focus è sul non-owner.
  await expectConfigButtonVisible(page, false);

  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await expectConfigButtonVisible(page, true);

  await openInstanceConfigScreen(page);
  await fillInstanceConfigForm(page, values);
  await page
    .getByRole('button', { name: 'Salva configurazione', exact: true })
    .click();

  await expect(
    page.getByText('Configurazione salvata', { exact: true }).first(),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(page.getByText('owner required')).not.toBeVisible({
    timeout: 1_000,
  });
  await expectInstanceConfigInDb(values);
});

test('promote dopo login: save senza logout', async ({ page }) => {
  const stamp = Date.now();
  const user = await createLocalConfirmedUser(`late${stamp}`);

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await clearAppData(page);
  await loginInAuthForm(page, user.email, user.password);
  await waitForLoggedInShell(page);

  promoteProfileToOwner(user.userId);

  // L'inbox rivaluta is_instance_owner al boot — senza reload il pulsante resta nascosto.
  await page.reload({ waitUntil: 'domcontentloaded', timeout: E2E_TIMEOUT.boot });
  await waitForLoggedInShell(page);
  await enableFlutterAccessibility(page);
  await expectConfigButtonVisible(page, true);

  const values: InstanceConfigExpectation = {
    displayName: `E2E Late owner ${stamp}`,
    imServerId: `e2e-late-${stamp}.alfred.im`,
    logoUrl: `https://example.com/e2e/late-${stamp}.png`,
    themeColor: '#445566',
    privacyUrl: `https://example.com/e2e/privacy-late-${stamp}`,
    termsUrl: `https://example.com/e2e/terms-late-${stamp}`,
    supportUrl: `https://example.com/e2e/support-late-${stamp}`,
  };

  await openInstanceConfigScreen(page);
  await fillInstanceConfigForm(page, values);
  await page
    .getByRole('button', { name: 'Salva configurazione', exact: true })
    .click();

  await expect(
    page.getByText('Configurazione salvata', { exact: true }).first(),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(page.getByText('owner required')).not.toBeVisible({
    timeout: 1_000,
  });
  await expectInstanceConfigInDb(values);
});
