// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import {
  addReceptionAllowlist,
  configureLocalPushSettings,
  sendMessageToProfile,
} from './helpers/local-push-setup';
import {
  createLocalConfirmedUser,
  isLocalSupabaseStack,
  type LocalE2eUser,
} from './helpers/local-auth';
import {
  BASE_URL,
  clearAppData,
  clickAggiungiAccount,
  expectManifestCount,
  expectMultiAccountList,
  loginInAuthForm,
  manifestEntryForUsername,
  switchToAccountByDisplayName,
  waitForAuthForm,
  waitForChatInput,
  waitForLoggedInShell,
} from './helpers/multi-account';
import { readSavedAccountsManifest } from './helpers/flutter-a11y';
import {
  deliverPushInServiceWorker,
  ensurePushSubscriptionInDb,
  expectFocusedUserId,
  forceNotificationPermission,
  installNotificationPermissionMock,
  installPushSubscribeMock,
  simulateNotificationTap,
} from './helpers/push';
import { loginSupabase } from './helpers/supabase-api';
import { E2E_TIMEOUT } from './helpers/timeouts';

/**
 * Tap notifica push con due account aperti: focus su A, push per B → tap → focus B + chat.
 * Solo stack locale (nessun account utente sul live).
 */
test.use({
  viewport: { width: 390, height: 844 },
  permissions: ['notifications'],
});
test.setTimeout(180_000);

test.beforeAll(() => {
  test.skip(
    !isLocalSupabaseStack(),
    'push-tap-multi-account richiede SUPABASE_URL locale',
  );
  test.skip(
    !(process.env.ALFRED_BASE_URL ?? '').match(/localhost|127\.0\.0\.1/),
    'push-tap-multi-account richiede ALFRED_BASE_URL locale',
  );
  configureLocalPushSettings();
});

async function setupTwoLocalAccounts(
  page: import('@playwright/test').Page,
  acct1: LocalE2eUser,
  acct2: LocalE2eUser,
) {
  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await clearAppData(page);
  await loginInAuthForm(page, acct1.email, acct1.password);
  expectManifestCount(await readSavedAccountsManifest(page), 1);
  await expectMultiAccountList(page, false);

  await clickAggiungiAccount(page);
  await waitForAuthForm(page);
  await loginInAuthForm(page, acct2.email, acct2.password, {
    minAccounts: 2,
  });
  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  const manifest = (await readSavedAccountsManifest(page))!;
  return {
    account1: manifestEntryForUsername(manifest, acct1.username),
    account2: manifestEntryForUsername(manifest, acct2.username),
  };
}

test('tap push con focus su altro account apre chat destinatario', async ({
  page,
  context,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => {
    if (err.message.includes('InboxController was used after being disposed')) {
      return;
    }
    errors.push(err.message);
  });

  const acct1 = await createLocalConfirmedUser('tap1');
  const acct2 = await createLocalConfirmedUser('tap2');

  const session1 = await loginSupabase(acct1.email, acct1.password);
  const session2 = await loginSupabase(acct2.email, acct2.password);

  await addReceptionAllowlist({
    ownerUserId: acct1.userId,
    allowedProfileId: acct2.userId,
    ownerAccessToken: session1.accessToken,
  });
  await addReceptionAllowlist({
    ownerUserId: acct2.userId,
    allowedProfileId: acct1.userId,
    ownerAccessToken: session2.accessToken,
  });

  await installPushSubscribeMock(page);
  await installNotificationPermissionMock(page);

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await forceNotificationPermission(page, new URL(BASE_URL).origin);
  await context.grantPermissions(['notifications'], {
    origin: new URL(BASE_URL).origin,
  });

  const { account1, account2 } = await setupTwoLocalAccounts(
    page,
    acct1,
    acct2,
  );

  // Focus su account 1 (utente «sul conto sbagliato» rispetto alla push per account 2).
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await expectFocusedUserId(page, account1.userId);

  await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.register('push_sw.js');
    await navigator.serviceWorker.ready;
    await reg.pushManager.subscribe({ userVisibleOnly: true });
  });

  await ensurePushSubscriptionInDb({
    page,
    accessToken: session2.accessToken,
    userId: acct2.userId,
  });

  const messageBody = `e2e push tap ${Date.now()}`;
  await sendMessageToProfile({
    senderAccessToken: session1.accessToken,
    recipientProfileId: acct2.userId,
    body: messageBody,
    clientMessageId: `e2e-push-tap-${Date.now()}`,
  });

  const swPayload = {
    recipientUserId: acct2.userId,
    peerProfileId: acct1.userId,
    peerDisplayName: account1.displayName ?? acct1.username,
    recipientUsername: acct2.username,
    previewText: messageBody,
  };

  await deliverPushInServiceWorker(page, swPayload);

  await simulateNotificationTap(page, {
    recipientUserId: acct2.userId,
    peerProfileId: acct1.userId,
    previewText: messageBody,
  });

  await expectFocusedUserId(page, account2.userId);
  await waitForChatInput(page);
  await expect(page.getByText(messageBody)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
