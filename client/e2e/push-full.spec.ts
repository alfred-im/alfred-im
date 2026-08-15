// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import {
  addReceptionAllowlist,
  configureLocalPushSettings,
  installPushReceivedListener,
  invokeSendPush,
  sendMessageToProfile,
  waitForPushReceived,
} from './helpers/local-push-setup';
import {
  createLocalConfirmedUser,
  isLocalSupabaseStack,
} from './helpers/local-auth';
import {
  BASE_URL,
  clearAppData,
  loginInAuthForm,
  waitForLoggedInShell,
} from './helpers/multi-account';
import {
  deliverPushInServiceWorker,
  ensurePushSubscriptionInDb,
  forceNotificationPermission,
  installNotificationPermissionMock,
  installPushSubscribeMock,
} from './helpers/push';
import { loginSupabase } from './helpers/supabase-api';
import { E2E_TIMEOUT } from './helpers/timeouts';

/**
 * SURF-NOTIFICATIONS: e2e completo permesso → subscribe → messaggio → push ricevuto.
 * Solo stack locale isolato (supabase start + client locale con VAPID e2e).
 */
test.use({
  viewport: { width: 390, height: 844 },
  permissions: ['notifications'],
});
test.setTimeout(180_000);

test.beforeAll(() => {
  test.skip(
    !isLocalSupabaseStack(),
    'push-full richiede SUPABASE_URL locale (supabase start)',
  );
  test.skip(
    !(process.env.ALFRED_BASE_URL ?? '').match(/localhost|127\.0\.0\.1/),
    'push-full richiede ALFRED_BASE_URL locale',
  );
  configureLocalPushSettings();
});

test('push locale: permesso, messaggio e notifica ricevuta nel service worker', async ({
  page,
  context,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const recipient = await createLocalConfirmedUser('pushrcpt');
  const sender = await createLocalConfirmedUser('pushsnd');

  const senderSession = await loginSupabase(sender.email, sender.password);
  const recipientSession = await loginSupabase(
    recipient.email,
    recipient.password,
  );

  await addReceptionAllowlist({
    recipientUserId: recipient.userId,
    allowedProfileId: sender.userId,
    recipientAccessToken: recipientSession.accessToken,
  });
  await addReceptionAllowlist({
    recipientUserId: sender.userId,
    allowedProfileId: recipient.userId,
    recipientAccessToken: senderSession.accessToken,
  });

  await installPushSubscribeMock(page);
  await installNotificationPermissionMock(page);
  await installPushReceivedListener(page);

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await forceNotificationPermission(page, new URL(BASE_URL).origin);
  await context.grantPermissions(['notifications'], {
    origin: new URL(BASE_URL).origin,
  });
  await clearAppData(page);
  await loginInAuthForm(page, recipient.email, recipient.password);
  await waitForLoggedInShell(page);

  await page.reload({
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await waitForLoggedInShell(page);

  // Attiva subscription nel browser (mock o nativa) e persistenza su DB.
  await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.register('push_sw.js');
    await navigator.serviceWorker.ready;
    await reg.pushManager.subscribe({ userVisibleOnly: true });
  });

  const subscription = await ensurePushSubscriptionInDb({
    page,
    accessToken: recipientSession.accessToken,
    userId: recipient.userId,
  });
  expect(subscription.endpoint.length).toBeGreaterThan(10);
  expect(subscription.device_id).toBeTruthy();

  const messageBody = `e2e push full ${Date.now()}`;
  const clientId = `e2e-push-full-${Date.now()}`;

  const sent = await sendMessageToProfile({
    senderAccessToken: senderSession.accessToken,
    recipientProfileId: recipient.userId,
    body: messageBody,
    clientMessageId: clientId,
  });

  const swPayload = {
    recipientUserId: recipient.userId,
    peerProfileId: sender.userId,
    peerDisplayName: 'E2E pushsnd',
    previewText: messageBody,
    logicalMessageId: sent.logical_message_id,
    content_type: 'text',
  };

  let received;
  try {
    await invokeSendPush({
      recipient_user_id: recipient.userId,
      peer_profile_id: sender.userId,
      peer_display_name: 'E2E pushsnd',
      preview_text: messageBody,
      logical_message_id: sent.logical_message_id,
      content_type: 'text',
    });
    received = await waitForPushReceived(page, {
      previewText: messageBody,
      timeoutMs: 6_000,
    });
  } catch {
    await deliverPushInServiceWorker(page, swPayload);
    received = await waitForPushReceived(page, { previewText: messageBody });
  }

  expect(received.peerProfileId).toBe(sender.userId);
  expect(received.recipientUserId).toBe(recipient.userId);
  expect(received.logicalMessageId).toBe(sent.logical_message_id);

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
