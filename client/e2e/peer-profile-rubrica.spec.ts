// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * E2E UX — rubrica da overlay profilo (tap «Aggiungi» → pulsante aggiornato).
 *
 * Cattura il bug telefono: profilo mostra «Aggiungi alla rubrica», tap,
 * nessun PostgrestException, label diventa «Rimuovi dalla rubrica».
 *
 * Gate: `bash scripts/test.sh e2e-nav-local`
 */
import { test, expect } from '@playwright/test';

import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import { isLocalSupabaseStack } from './helpers/local-auth';
import { setupTwoLocalAccounts } from './helpers/local-multi-account';
import {
  expectContactAbsentInDb,
  expectContactInDb,
  expectNoRelationshipError,
  openPeerProfileFromChatHeader,
  prepareLocalPeerRelationshipPair,
  prepareLocalPeerWithRubricaAndConsent,
} from './helpers/peer-relationship';
import {
  BASE_URL,
  openPeerInInboxView,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(120_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede stack locale');
});

test('overlay da chat: Aggiungi alla rubrica aggiorna il pulsante', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } = await prepareLocalPeerRelationshipPair(
    `rp1${stamp}`,
    `rp2${stamp}`,
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

  await enableFlutterAccessibility(page);
  await openPeerInInboxView(page, account2.displayName ?? acct2.username);
  await expect(page.getByText(seedMessage)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  await openPeerProfileFromChatHeader(page);

  const addButton = page.getByRole('button', {
    name: 'Aggiungi alla rubrica',
    exact: true,
  });
  await expect(addButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });

  await addButton.click();
  await page.waitForTimeout(800);
  await expectNoRelationshipError(page);
  await expectContactInDb(acct1.userId, acct2.userId);

  await expect(
    page.getByRole('button', { name: 'Rimuovi dalla rubrica', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(addButton).not.toBeVisible({ timeout: 2_000 });
});

test('overlay da chat dopo switch: ciclo Rimuovi → Aggiungi', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } =
    await prepareLocalPeerWithRubricaAndConsent(`st1${stamp}`, `st2${stamp}`);

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
  await openPeerInInboxView(page, account2.displayName ?? acct2.username);
  await expect(page.getByText(seedMessage)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  await openPeerProfileFromChatHeader(page);

  const removeButton = page.getByRole('button', {
    name: 'Rimuovi dalla rubrica',
    exact: true,
  });
  await expect(removeButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });

  await removeButton.click();
  await page.waitForTimeout(800);
  await expectNoRelationshipError(page);
  await expectContactAbsentInDb(acct1.userId, acct2.userId);

  const addButton = page.getByRole('button', {
    name: 'Aggiungi alla rubrica',
    exact: true,
  });
  await expect(addButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await addButton.click();
  await page.waitForTimeout(800);
  await expectNoRelationshipError(page);
  await expectContactInDb(acct1.userId, acct2.userId);
  await expect(removeButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });
});

test('overlay da inbox (senza chat): Aggiungi aggiorna pulsante', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, seedMessage } = await prepareLocalPeerRelationshipPair(
    `in1${stamp}`,
    `in2${stamp}`,
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

  await enableFlutterAccessibility(page);
  await expect(page.getByRole('button', { name: 'Nuovo messaggio' })).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
  await expect(page.getByText(seedMessage)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  const peerLabel = account2.displayName ?? acct2.username;
  const peerRow = page
    .getByRole('button', { name: new RegExp(peerLabel) })
    .filter({ hasNotText: /@/ })
    .first();
  await expect(peerRow).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await peerRow
    .getByRole('button', { name: 'Apri profilo', exact: true })
    .click();

  const addButton = page.getByRole('button', {
    name: 'Aggiungi alla rubrica',
    exact: true,
  });
  await expect(addButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await addButton.click();
  await page.waitForTimeout(800);
  await expectNoRelationshipError(page);
  await expectContactInDb(acct1.userId, acct2.userId);

  await expect(
    page.getByRole('button', { name: 'Rimuovi dalla rubrica', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
});
