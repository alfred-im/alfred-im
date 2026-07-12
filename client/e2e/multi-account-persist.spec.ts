// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import {
  enableFlutterAccessibility,
  readSavedAccountsManifest,
} from './helpers/flutter-a11y';
import {
  ACCOUNT1,
  ACCOUNT2,
  clearAppData,
  clickAggiungiAccount,
  expectLoggedInShell,
  expectManifestCount,
  expectMultiAccountList,
  loginInAuthForm,
  waitForAuthForm,
  waitForLoggedInShell,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

/**
 * Flusso utente (mobile, demo live):
 * 1. pulisci dati → login account 1
 * 2. aggiungi account 2 → compaiono 2 account (sezione «Altri account»)
 * 3. F5 → devono restare 2 account (se il 2° sparisce, «Altri account» non c’è)
 */
test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(90_000);

test('multi-account mobile: dopo F5 restano 2 account in lista (flusso utente)', async ({
  page,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const base =
    process.env.ALFRED_BASE_URL ?? 'https://alfred-im.github.io/alfred-im/';
  await page.goto(base, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await clearAppData(page);
  await loginInAuthForm(page, ACCOUNT1.email, ACCOUNT1.password);
  expectManifestCount(await readSavedAccountsManifest(page), 1);
  await expectMultiAccountList(page, false);

  await clickAggiungiAccount(page);
  await waitForAuthForm(page);
  await loginInAuthForm(page, ACCOUNT2.email, ACCOUNT2.password, {
    minAccounts: 2,
  });
  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  await page.reload({ waitUntil: 'domcontentloaded', timeout: E2E_TIMEOUT.boot });
  await waitForLoggedInShell(page);
  await enableFlutterAccessibility(page);

  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
