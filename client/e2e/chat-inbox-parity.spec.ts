// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Gate — anteprima inbox e chat devono mostrare gli stessi messaggi.
 * Cattura: fetch scartato da scope guard → preview sì, chat vuota.
 */
import { test, expect } from '@playwright/test';

import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  prepareLocalMessagingPair,
  setupTwoLocalAccounts,
} from './helpers/local-multi-account';
import {
  BASE_URL,
  backToInboxFromChat,
  composeNewMessage,
  openPeerInInbox,
  sendChatMessage,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(120_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('messaggio in anteprima inbox compare anche in chat', async ({ page }) => {
  const stamp = Date.now();
  const msg = `inbox-chat-parity-${stamp}`;
  const { acct1, acct2 } = await prepareLocalMessagingPair(
    `icp${stamp}`,
    `icpb${stamp}`,
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

  await composeNewMessage(page, acct2.username);
  await sendChatMessage(page, msg);
  await backToInboxFromChat(page);

  await expect(page.getByText(msg).first()).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  await openPeerInInbox(page, account2.displayName!);
  await expect(page.getByText(msg)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });
});
