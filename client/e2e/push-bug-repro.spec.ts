// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Riproduzione manuale-agente: A in focus, messaggio a B, tap notifica per B.
 * Percorso notificationclick reale (non simulateNotificationTap).
 * Cattura log [alfred][push] in console.
 */
import { test, expect } from '@playwright/test';

import { expectFocusedUserId, readFocusedUserId } from './helpers/focus';
import { configureLocalPushSettings } from './helpers/local-push-setup';
import {
  prepareLocalMessagingPair,
  setupTwoLocalAccounts,
} from './helpers/local-multi-account';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  BASE_URL,
  composeNewMessage,
  sendChatMessage,
  switchToAccountByDisplayName,
  waitForChatInput,
} from './helpers/multi-account';
import {
  deliverPushInServiceWorker,
  ensurePushSubscriptionInDb,
  installPushTestEnvironment,
} from './helpers/push';
import {
  attachDiagnosticLogCollector,
  dumpDiagnosticLogsOnFailure,
  formatDiagnosticLogsFooter,
} from './helpers/diagnostic-logs';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({
  viewport: { width: 390, height: 844 },
  permissions: ['notifications'],
  headless: false,
});
test.setTimeout(300_000);

let diagLogs: string[] = [];

test.beforeEach(({ page }) => {
  diagLogs = attachDiagnosticLogCollector(page);
});

test.afterEach(({}, testInfo) => {
  dumpDiagnosticLogsOnFailure(diagLogs, testInfo);
});

test.beforeAll(() => {
  test.skip(!!process.env.CI, 'push-bug-repro: solo agente locale (headed)');
  test.skip(!isLocalSupabaseStack(), 'stack locale richiesto');
  test.skip(
    !(process.env.ALFRED_BASE_URL ?? 'http://localhost:8080/').match(
      /localhost|127\.0\.0\.1/,
    ),
    'ALFRED_BASE_URL locale richiesto',
  );
  configureLocalPushSettings();
});

test('A scrive a B, tap notifica B con notificationclick reale', async ({
  page,
  context,
}) => {
  const diagFooter = () => formatDiagnosticLogsFooter(diagLogs);

  const { acct1, acct2, session1, session2 } =
    await prepareLocalMessagingPair('bugA', 'bugB');

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

  // Focus su account A
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );
  await expectFocusedUserId(page, account1.userId);

  // Come l'utente: A in focus, chat aperta verso B
  await composeNewMessage(page, acct2.username);
  const messageBody = `bug repro ${Date.now()}`;
  await sendChatMessage(page, messageBody);

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

  const messageBodyAlreadySent = messageBody;
  await deliverPushInServiceWorker(page, {
    recipientUserId: acct2.userId,
    peerProfileId: acct1.userId,
    peerDisplayName: account1.displayName ?? acct1.username,
    recipientUsername: acct2.username,
    previewText: messageBodyAlreadySent,
  });

  const sw =
    page.context().serviceWorkers()[0] ??
    (await page.context().waitForEvent('serviceworker', { timeout: 15_000 }));

  const swDiagnostics = await sw.evaluate(async () => {
    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    const notifications = await self.registration.getNotifications();
    return {
      clientCount: clients.length,
      clientUrls: clients.map((c) => c.url),
      notificationCount: notifications.length,
    };
  });
  console.log('=== SW BEFORE CLICK ===', JSON.stringify(swDiagnostics));

  const clickResult = await sw.evaluate(async () => {
    const notifications = await self.registration.getNotifications();
    if (notifications.length === 0) {
      return { ok: false, reason: 'no_notification' };
    }
    const notification = notifications[0]!;
    const data = notification.data ?? {};
    const conversation = {
      owner: data.recipientUserId || data.recipient_user_id,
      peer: data.peerProfileId || data.peer_profile_id,
    };
    try {
      self.dispatchEvent(
        new NotificationEvent('notificationclick', { notification }),
      );
      return { ok: true, path: 'notificationclick_event', conversation };
    } catch (e) {
      return {
        ok: false,
        reason: 'dispatch_failed',
        error: String(e),
        conversation,
      };
    }
  });

  expect(clickResult.ok, JSON.stringify(clickResult)).toBe(true);

  await page.waitForTimeout(2_000);

  const focusAfter = await readFocusedUserId(page);
  const focusedB = focusAfter === acct2.userId;

  expect(
    diagLogs.some((l) => l.includes('sw.message') || l.includes('open_chat.emit')),
    `tap deve arrivare via sw.message; ${diagFooter()}`,
  ).toBe(true);

  expect(
    focusedB,
    `focus atteso B (${acct2.userId}); ${diagFooter()}`,
  ).toBe(true);

  await waitForChatInput(page);
  await expect(page.getByText(messageBodyAlreadySent)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });
});
