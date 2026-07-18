// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import { expectFocusedUserId } from './helpers/focus';
import { configureLocalPushSettings, sendMessageToProfile } from './helpers/local-push-setup';
import {
  prepareLocalMessagingPair,
  setupTwoLocalAccounts,
} from './helpers/local-multi-account';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  BASE_URL,
  switchToAccountByDisplayName,
  waitForChatInput,
} from './helpers/multi-account';
import {
  attachDiagnosticLogCollector,
  dumpDiagnosticLogsOnFailure,
  formatDiagnosticLogsFooter,
} from './helpers/diagnostic-logs';
import { attachPageErrorCollector } from './helpers/page-errors';
import {
  deliverPushInServiceWorker,
  ensurePushSubscriptionInDb,
  installPushTestEnvironment,
  simulateNotificationTap,
} from './helpers/push';
import { E2E_TIMEOUT } from './helpers/timeouts';

/**
 * Tap push multi-account: focus su A, notifica per B → tap → focus B + chat col mittente.
 * Stack locale isolato (`supabase start` + Flutter su localhost con VAPID e2e).
 *
 * Lancio: `bash scripts/test.sh e2e-push-local`
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

let diagLogs: string[] = [];

test.beforeEach(({ page }) => {
  diagLogs = attachDiagnosticLogCollector(page);
});

test.afterEach(({}, testInfo) => {
  dumpDiagnosticLogsOnFailure(diagLogs, testInfo);
});

test('tap push con focus su altro account apre chat destinatario', async ({
  page,
  context,
}) => {
  const errors = attachPageErrorCollector(page);
  const diagFooter = () => formatDiagnosticLogsFooter(diagLogs);

  const { acct1, acct2, session1, session2 } =
    await prepareLocalMessagingPair('tap1', 'tap2');

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await installPushTestEnvironment(page, context, BASE_URL);

  const { account1, account2 } = await setupTwoLocalAccounts(
    page,
    acct1,
    acct2,
  );

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

  await deliverPushInServiceWorker(page, {
    recipientUserId: acct2.userId,
    peerProfileId: acct1.userId,
    peerDisplayName: account1.displayName ?? acct1.username,
    recipientUsername: acct2.username,
    previewText: messageBody,
  });

  await simulateNotificationTap(page, {
    recipientUserId: acct2.userId,
    peerProfileId: acct1.userId,
  });

  await expectFocusedUserId(page, account2.userId);
  await waitForChatInput(page);
  await expect(page.getByText(messageBody)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  expect(
    diagLogs.some(
      (line) =>
        line.includes('open_on_account.ok') ||
        line.includes('resolve_peer') ||
        line.includes('[nav]'),
    ),
    `percorso navigazione push atteso; ${diagFooter()}`,
  ).toBe(true);

  expect(errors, `errori JS: ${errors.join('; ')}; ${diagFooter()}`).toEqual(
    [],
  );
});
