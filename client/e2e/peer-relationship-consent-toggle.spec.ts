// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * E2E UX — ciclo consenso da overlay profilo (profilo già consentito).
 *
 * Percorso telefono:
 * 1. Apri chat con peer già in allow list
 * 2. Apri profilo → switch «Consenti messaggi» è ON
 * 3. Revoca consenso (toggle OFF) — nessun errore, riga assente in DB
 * 4. Concedi di nuovo consenso (toggle ON) — nessun 23505 duplicate key
 *
 * Gate: `bash scripts/test.sh e2e-nav-local`
 */
import { test, expect } from '@playwright/test';

import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import { isLocalSupabaseStack } from './helpers/local-auth';
import { setupTwoLocalAccounts } from './helpers/local-multi-account';
import {
  expectAllowlistAbsentInDb,
  expectAllowlistInDb,
  expectNoRelationshipError,
  closeChatHeaderMenu,
  openChatHeaderMenu,
  openPeerProfileFromChatHeader,
  prepareLocalConsentedPeerPair,
  selectChatHeaderMenuItem,
} from './helpers/peer-relationship';
import { BASE_URL, openPeerInInboxView, switchToAccountByDisplayName } from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(180_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('overlay profilo: revoca e riconcedi consenso senza errore', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } = await prepareLocalConsentedPeerPair(
    `ct1${stamp}`,
    `ct2${stamp}`,
  );

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });

  const { account1, account2 } = await setupTwoLocalAccounts(page, acct1, acct2);

  // Restore sessione come sul telefono — cache controller spesso vuota dopo switch.
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await switchToAccountByDisplayName(
    page,
    account2.displayName!,
    account2.userId,
  );
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );

  await enableFlutterAccessibility(page);
  const peerLabel = account2.displayName ?? acct2.username;
  await openPeerInInboxView(page, peerLabel);
  await expect(page.getByText(seedMessage)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  await openPeerProfileFromChatHeader(page);

  const allowSwitch = page.getByRole('switch', { name: /Consenti messaggi/ });
  await expect(allowSwitch).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(allowSwitch).toBeChecked({ timeout: E2E_TIMEOUT.ui });

  // --- Revoca consenso (UI) ---
  await allowSwitch.click();
  await page.waitForTimeout(600);
  await expectNoRelationshipError(page);
  await expectAllowlistAbsentInDb(acct1.userId, acct2.userId);
  await expect(allowSwitch).not.toBeChecked({ timeout: E2E_TIMEOUT.ui });

  // --- Riconcedi consenso (UI) — deve evitare 23505 se riga già presente ---
  await allowSwitch.click();
  await page.waitForTimeout(600);
  await expectNoRelationshipError(page);
  await expectAllowlistInDb(acct1.userId, acct2.userId);
  await expect(allowSwitch).toBeChecked({ timeout: E2E_TIMEOUT.ui });

  await page.getByRole('button', { name: 'Chiudi' }).click();
  await expect(allowSwitch).not.toBeVisible({ timeout: E2E_TIMEOUT.ui });
});

test('menu header: revoca e riconcedi consenso dopo switch account', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } = await prepareLocalConsentedPeerPair(
    `cm1${stamp}`,
    `cm2${stamp}`,
  );

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });

  const { account1, account2 } = await setupTwoLocalAccounts(page, acct1, acct2);

  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await switchToAccountByDisplayName(
    page,
    account2.displayName!,
    account2.userId,
  );
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );

  await enableFlutterAccessibility(page);
  const peerLabel = account2.displayName ?? acct2.username;
  await openPeerInInboxView(page, peerLabel);
  await expect(page.getByText(seedMessage)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  // Peer già in allow list — menu deve mostrare «Revoca», non «Consenti».
  await openChatHeaderMenu(page);
  await expect(
    page.getByRole('menuitem', { name: 'Revoca', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(
    page.getByRole('menuitem', { name: 'Consenti', exact: true }),
  ).not.toBeVisible({ timeout: 2_000 });

  await selectChatHeaderMenuItem(page, 'Revoca');
  await expectNoRelationshipError(page);
  await expectAllowlistAbsentInDb(acct1.userId, acct2.userId);

  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Consenti');
  await expectNoRelationshipError(page);
  await expectAllowlistInDb(acct1.userId, acct2.userId);

  await closeChatHeaderMenu(page);
});
