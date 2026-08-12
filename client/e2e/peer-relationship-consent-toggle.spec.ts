// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * E2E UX — rubrica e consenso in parallelo (profilo già in rubrica e consentito).
 *
 * Percorso telefono dopo switch account:
 * 1. Menu ⋮ mostra «Rimuovi dalla rubrica» + «Revoca» (non Aggiungi/Consenti)
 * 2. Ciclo rubrica da menu: rimuovi → riaggiungi (cattura 23505 contacts_owner_linked_profile_idx)
 * 3. Ciclo consenso da menu: revoca → concedi (cattura 23505 reception_allowlist)
 * 4. Stesso ciclo da overlay profilo (switch + pulsante rubrica)
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
  expectContactAbsentInDb,
  expectContactInDb,
  expectNoRelationshipError,
  closeChatHeaderMenu,
  openChatHeaderMenu,
  openPeerProfileFromChatHeader,
  prepareLocalPeerWithRubricaAndConsent,
  selectChatHeaderMenuItem,
} from './helpers/peer-relationship';
import {
  BASE_URL,
  openPeerInInboxView,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(240_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('rubrica e consenso insieme: ciclo revoca/riconcessione da menu e profilo', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } =
    await prepareLocalPeerWithRubricaAndConsent(`rc1${stamp}`, `rc2${stamp}`);

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

  // --- Menu ⋮: stato iniziale (già in rubrica e consentito) ---
  await openChatHeaderMenu(page);
  await expect(
    page.getByRole('menuitem', { name: 'Rimuovi dalla rubrica', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(
    page.getByRole('menuitem', { name: 'Revoca', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(
    page.getByRole('menuitem', { name: 'Aggiungi alla rubrica', exact: true }),
  ).not.toBeVisible({ timeout: 2_000 });
  await expect(
    page.getByRole('menuitem', { name: 'Consenti', exact: true }),
  ).not.toBeVisible({ timeout: 2_000 });
  await page.keyboard.press('Escape');
  await closeChatHeaderMenu(page);

  // --- Menu ⋮: ciclo rubrica ---
  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Rimuovi dalla rubrica');
  await expectNoRelationshipError(page);
  await expectContactAbsentInDb(acct1.userId, acct2.userId);

  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Aggiungi alla rubrica');
  await expectNoRelationshipError(page);
  await expectContactInDb(acct1.userId, acct2.userId);

  // --- Menu ⋮: ciclo consenso (subito dopo rubrica) ---
  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Revoca');
  await expectNoRelationshipError(page);
  await expectAllowlistAbsentInDb(acct1.userId, acct2.userId);

  await openChatHeaderMenu(page);
  await selectChatHeaderMenuItem(page, 'Consenti');
  await expectNoRelationshipError(page);
  await expectAllowlistInDb(acct1.userId, acct2.userId);
  await closeChatHeaderMenu(page);

  // --- Overlay profilo: stesso ciclo parallelo ---
  await openPeerProfileFromChatHeader(page);

  const allowSwitch = page.getByRole('switch', { name: /Consenti messaggi/ });
  const rubricaButton = page.getByRole('button', {
    name: 'Rimuovi dalla rubrica',
    exact: true,
  });

  await expect(allowSwitch).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(rubricaButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(allowSwitch).toBeChecked({ timeout: E2E_TIMEOUT.ui });

  // Rubrica via profilo
  await rubricaButton.click();
  await page.waitForTimeout(600);
  await expectNoRelationshipError(page);
  await expectContactAbsentInDb(acct1.userId, acct2.userId);
  await expect(
    page.getByRole('button', { name: 'Aggiungi alla rubrica', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });

  await page
    .getByRole('button', { name: 'Aggiungi alla rubrica', exact: true })
    .click();
  await page.waitForTimeout(600);
  await expectNoRelationshipError(page);
  await expectContactInDb(acct1.userId, acct2.userId);

  // Consenso via profilo
  await allowSwitch.click();
  await page.waitForTimeout(600);
  await expectNoRelationshipError(page);
  await expectAllowlistAbsentInDb(acct1.userId, acct2.userId);
  await expect(allowSwitch).not.toBeChecked({ timeout: E2E_TIMEOUT.ui });

  await allowSwitch.click();
  await page.waitForTimeout(600);
  await expectNoRelationshipError(page);
  await expectAllowlistInDb(acct1.userId, acct2.userId);
  await expect(allowSwitch).toBeChecked({ timeout: E2E_TIMEOUT.ui });

  await page.getByRole('button', { name: 'Chiudi' }).click();
  await expect(allowSwitch).not.toBeVisible({ timeout: E2E_TIMEOUT.ui });
});
