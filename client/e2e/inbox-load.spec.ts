// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import {
  BASE_URL,
  loginInAuthForm,
  waitForLoggedInShell,
} from './helpers/multi-account';
import { createLocalConfirmedUser, isLocalSupabaseStack } from './helpers/local-auth';
import { enableFlutterAccessibility } from './helpers/flutter-a11y';

async function enableA11y(page: import('@playwright/test').Page) {
  await enableFlutterAccessibility(page);
}

/**
 * Inbox deve comparire senza interazione (digitare nella ricerca non deve
 * essere necessario per uscire dalla rotella).
 */
test('lista conversazioni si carica senza digitare nella ricerca', async ({
  page,
}) => {
  test.skip(!isLocalSupabaseStack(), 'richiede stack Supabase locale');
  test.skip(
    !(process.env.ALFRED_BASE_URL ?? BASE_URL).match(/localhost|127\.0\.0\.1/),
    'richiede ALFRED_BASE_URL locale',
  );

  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const user = await createLocalConfirmedUser('inbox');

  await page.goto(BASE_URL, {
    waitUntil: 'networkidle',
    timeout: 90_000,
  });
  await enableA11y(page);

  await loginInAuthForm(page, user.email, user.password);
  await waitForLoggedInShell(page);

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
