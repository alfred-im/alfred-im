// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import {
  enableFlutterAccessibility,
  readSavedAccountsManifest,
} from './helpers/flutter-a11y';
import { createLocalConfirmedUser, isLocalSupabaseStack } from './helpers/local-auth';
import { setupTwoLocalAccounts } from './helpers/local-multi-account';
import {
  expectManifestCount,
  expectMultiAccountList,
  waitForLoggedInShell,
  waitForAppBoot,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

/**
 * Flusso utente (mobile):
 * 1. pulisci dati → login account 1
 * 2. aggiungi account 2 → compaiono 2 account (sezione «Altri account»)
 * 3. F5 → devono restare 2 account (se il 2° sparisce, «Altri account» non c’è)
 */
test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(90_000);

test('multi-account mobile: dopo F5 restano 2 account in lista (stack locale)', async ({
  page,
}) => {
  test.skip(!isLocalSupabaseStack(), 'richiede stack Supabase locale');

  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const acct1 = await createLocalConfirmedUser('mp1');
  const acct2 = await createLocalConfirmedUser('mp2');
  await setupTwoLocalAccounts(page, acct1, acct2);

  await page.reload({ waitUntil: 'domcontentloaded', timeout: E2E_TIMEOUT.boot });
  await waitForAppBoot(page);
  await waitForLoggedInShell(page);
  await enableFlutterAccessibility(page);

  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
