// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Page } from '@playwright/test';

import {
  enableFlutterAccessibility,
  readSavedAccountsManifest,
  type ManifestEntry,
} from './flutter-a11y';
import type { LocalE2eUser } from './local-auth';
import {
  BASE_URL,
  clearAppData,
  clickAggiungiAccount,
  expectManifestCount,
  loginInAuthForm,
  manifestEntryForUsername,
  waitForAuthForm,
  waitForLoggedInShell,
} from './multi-account';
import { E2E_TIMEOUT } from './timeouts';

/** Login iniziale o aggiunta account senza wipe del manifest esistente. */
export async function ensureManifestAccounts(
  page: Page,
  accounts: LocalE2eUser[],
  options?: { wipe?: boolean },
): Promise<ManifestEntry[]> {
  if (accounts.length === 0) {
    throw new Error('ensureManifestAccounts: lista vuota');
  }

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });

  if (options?.wipe) {
    await clearAppData(page);
  }

  let manifest = await readSavedAccountsManifest(page);
  const loggedIn =
    manifest != null &&
    manifest.some((entry) => (entry.refreshToken?.length ?? 0) > 10);

  if (!loggedIn) {
    await loginInAuthForm(page, accounts[0].email, accounts[0].password);
    manifest = (await readSavedAccountsManifest(page))!;
  }

  for (let i = 1; i < accounts.length; i++) {
    const acct = accounts[i];
    manifest = (await readSavedAccountsManifest(page)) ?? [];
    const already = manifest.some((entry) => entry.userId === acct.userId);
    if (already) {
      continue;
    }
    await clickAggiungiAccount(page);
    await waitForAuthForm(page);
    await loginInAuthForm(page, acct.email, acct.password, {
      minAccounts: manifest.length + 1,
    });
  }

  await waitForLoggedInShell(page);
  const saved = (await readSavedAccountsManifest(page))!;
  expectManifestCount(saved, accounts.length);
  return saved;
}

export function manifestEntriesFor(
  saved: ManifestEntry[],
  accounts: LocalE2eUser[],
): ManifestEntry[] {
  return accounts.map((acct) => manifestEntryForUsername(saved, acct.username));
}

export async function ensureInboxShell(page: Page): Promise<void> {
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole('button', { name: 'Nuovo messaggio' }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}
