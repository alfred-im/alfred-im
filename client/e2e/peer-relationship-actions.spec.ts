// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * E2E UX — rubrica e consenso messaggi da menu header e overlay profilo.
 *
 * Riprodice il percorso telefono: due account, switch (restore sessione),
 * chat aperta, tap menu ⋮ e profilo, assert su Postgres.
 *
 * Gate: `bash scripts/test.sh e2e-nav-local`
 */
import { test, expect } from '@playwright/test';

import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import { isLocalSupabaseStack } from './helpers/local-auth';
import { setupTwoLocalAccounts } from './helpers/local-multi-account';
import {
  expectAllowlistInDb,
  expectContactInDb,
  expectNoRelationshipError,
  closeChatHeaderMenu,
  openChatHeaderMenu,
  openPeerProfileFromChatHeader,
  prepareLocalPeerRelationshipPair,
  selectChatHeaderMenuItem,
} from './helpers/peer-relationship';
import {
  BASE_URL,
  openPeerInInboxView,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(180_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('menu header e profilo: rubrica e consenso dopo switch account', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } = await prepareLocalPeerRelationshipPair(
    `pr1${stamp}`,
    `pr2${stamp}`,
  );

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });

  const { account1, account2 } = await setupTwoLocalAccounts(page, acct1, acct2);

  // Restore sessione: focus avanti e indietro come account-switch-restore.
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

  // --- Menu ⋮ header ---
  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Aggiungi alla rubrica');
  await expectNoRelationshipError(page);
  await expectContactInDb(acct1.userId, acct2.userId);

  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Consenti');
  await expectNoRelationshipError(page);
  await expectAllowlistInDb(acct1.userId, acct2.userId);

  await openChatHeaderMenu(page);
  await expect(
    page.getByRole('menuitem', { name: 'Rimuovi dalla rubrica', exact: true }),
  ).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
  await expect(
    page.getByRole('menuitem', { name: 'Revoca', exact: true }),
  ).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
  await page.keyboard.press('Escape');
  await closeChatHeaderMenu(page);

  // --- Overlay profilo (stesso flusso condiviso) ---
  await openPeerProfileFromChatHeader(page);
  const allowSwitch = page.getByRole('switch', { name: /Consenti messaggi/ });
  await expect(allowSwitch).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(
    page.getByRole('button', { name: 'Rimuovi dalla rubrica', exact: true }),
  ).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
  await expect(allowSwitch).toBeChecked({ timeout: E2E_TIMEOUT.ui });

  await page.getByRole('button', { name: 'Chiudi' }).click();
  await expect(allowSwitch).not.toBeVisible({ timeout: E2E_TIMEOUT.ui });
});
