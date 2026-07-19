// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Gate browser — tap inbox deve aprire la chat (input visibile), non spinner infinito.
 * Cattura il bug: openPeerOnFocusedAccount unawaited + isConversationReady senza scope.
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
  switchToAccountByDisplayName,
  waitForChatInput,
} from './helpers/multi-account';
import { E2E_TIMEOUT } from './helpers/timeouts';

const TEST_MSG = 'inbox-open-chat gate message';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(120_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('tap riga inbox apre chat con input messaggio (no spinner)', async ({
  page,
}) => {
  const stamp = Date.now();
  const { acct1, acct2, session1 } = await prepareLocalMessagingPair(
    `ioc${stamp}`,
    `iocb${stamp}`,
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
        p_client_message_id: `ioc-${stamp}`,
      }),
    },
  );
  expect(sendRes.ok, await sendRes.text()).toBeTruthy();

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
  const peerLabel = account2.displayName ?? acct2.username;
  await page.getByText(peerLabel).first().click({ timeout: E2E_TIMEOUT.ui });

  await waitForChatInput(page);
  await expect(page.getByText(TEST_MSG)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });

  const spinnerStuck = await page
    .locator('flt-semantics')
    .filter({ hasText: /CircularProgressIndicator/i })
    .isVisible()
    .catch(() => false);
  expect(spinnerStuck, 'chat non deve restare su spinner dopo tap inbox').toBe(
    false,
  );
});
