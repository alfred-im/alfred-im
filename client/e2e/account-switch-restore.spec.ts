// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Gate browser — switch account dalla sidebar: torna all'account con inbox
 * coerente; riaprendo il peer dalla inbox la chat è ripristinata (scope + messaggi).
 */
import { test, expect } from '@playwright/test';

import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  prepareLocalMessagingPair,
  setupTwoLocalAccounts,
} from './helpers/local-multi-account';
import {
  BASE_URL,
  backToInboxFromChat,
  openPeerInInbox,
  switchToAccountByDisplayName,
  waitForChatInput,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

const TEST_MSG = 'account-switch-restore gate message';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(120_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('switch sidebar ripristina chat aperta senza spinner', async ({ page }) => {
  const stamp = Date.now();
  const { acct1, acct2, session1 } = await prepareLocalMessagingPair(
    `asr${stamp}`,
    `asrb${stamp}`,
  );

  const supabaseUrl = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
  const anonKey =
    process.env.SUPABASE_ANON_KEY ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  const sendRes = await fetch(
    `${supabaseUrl}/rest/v1/rpc/send_message_to_profile`,
    {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${session1.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_recipient_profile_id: acct2.userId,
        p_body: TEST_MSG,
        p_client_message_id: `asr-${stamp}`,
      }),
    },
  );
  expect(sendRes.ok, await sendRes.text()).toBeTruthy();

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });

  const { account1, account2 } = await setupTwoLocalAccounts(page, acct1, acct2);

  // Focus su account1 (setupTwoLocalAccounts lascia focus su account2).
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    account1.userId,
  );

  await enableFlutterAccessibility(page);
  const peerLabel = account2.displayName ?? acct2.username;
  await page.getByText(peerLabel).first().click({ timeout: E2E_TIMEOUT.ui });
  await waitForChatInput(page);
  await expect(page.getByText(TEST_MSG)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  // Da chat mobile il drawer non è raggiungibile: torna a inbox come l'utente.
  await backToInboxFromChat(page);
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

  // Dopo backToInbox + switch, il prodotto mostra inbox (non auto-restore chat).
  await openPeerInInbox(page, peerLabel);
  await waitForChatInput(page);
  await expect(page.getByText(TEST_MSG)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  const spinnerStuck = await page
    .locator('flt-semantics')
    .filter({ hasText: /CircularProgressIndicator/i })
    .isVisible()
    .catch(() => false);
  expect(
    spinnerStuck,
    'dopo switch account la chat non deve restare su spinner',
  ).toBe(false);
});
