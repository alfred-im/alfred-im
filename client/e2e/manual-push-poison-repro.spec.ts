// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Riproduzione manuale automatizzata — tap push multi-account + messaggi veleno.
 * Stack reale: Flutter web + SW + Supabase locale (non flutter test).
 */
import { test, expect } from '@playwright/test';

import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import { expectFocusedUserId } from './helpers/focus';
import { prepareLocalMessagingPair, setupTwoLocalAccounts } from './helpers/local-multi-account';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  BASE_URL,
  switchToAccountByDisplayName,
  waitForChatInput,
} from './helpers/multi-account';
import {
  attachDiagnosticLogCollector,
  formatDiagnosticLogsFooter,
} from './helpers/diagnostic-logs';
import { installPushTestEnvironment, simulateNotificationTap } from './helpers/push';
import { E2E_TIMEOUT } from './helpers/timeouts';

const POISON_BY = 'VELENO_MAILBOX_B_VERSO_Y';
const MSG_A = 'ciao da A (legittimo push repro)';
const MSG_B = 'risposta precedente B push repro';

test.use({
  viewport: { width: 390, height: 844 },
  permissions: ['notifications'],
});
test.setTimeout(240_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede SUPABASE_URL locale');
});

test('riproduzione push tap — messaggi mailbox corretti', async ({
  page,
  context,
}) => {
  const diagLogs = attachDiagnosticLogCollector(page);
  const stamp = Date.now();

  const { acct1, acct2, session1, session2 } =
    await prepareLocalMessagingPair(`mpr${stamp}`, `mprb${stamp}`);

  const supabaseUrl = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
  const anonKey =
    process.env.SUPABASE_ANON_KEY ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  const send = async (
    jwt: string,
    recipient: string,
    body: string,
    cid: string,
  ) => {
    const res = await fetch(
      `${supabaseUrl}/rest/v1/rpc/send_message_to_profile`,
      {
        method: 'POST',
        headers: {
          apikey: anonKey,
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          p_recipient_profile_id: recipient,
          p_body: body,
          p_client_message_id: cid,
        }),
      },
    );
    if (!res.ok) {
      throw new Error(`send failed ${res.status}: ${await res.text()}`);
    }
  };

  // Terzo account Y per poison B|Y
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceKey) throw new Error('SUPABASE_SERVICE_ROLE_KEY mancante');
  const yUser = `mpry${stamp}`;
  const yRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: `${yUser}@e2e.local.test`,
      password: 'E2eLocalPass123!',
      email_confirm: true,
      user_metadata: { username: yUser, display_name: `E2E Y ${stamp}` },
    }),
  });
  const yJson = (await yRes.json()) as { id: string };
  const yId = yJson.id;

  await send(session1.accessToken, acct2.userId, MSG_A, `legit-a-${stamp}`);
  await send(session2.accessToken, acct1.userId, MSG_B, `legit-b-${stamp}`);
  await send(session2.accessToken, yId, POISON_BY, `poison-by-${stamp}`);

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

  // Apri chat A|B e attendi fetch (mailbox A)
  await enableFlutterAccessibility(page);
  await page.getByText(account2.displayName ?? acct2.username).first().click({
    timeout: E2E_TIMEOUT.ui,
  });
  await waitForChatInput(page);
  await expect(page.getByText(MSG_A)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });
  const peerBeforePush = account2.displayName ?? acct2.username;
  await page.screenshot({
    path: '/opt/cursor/artifacts/screenshots/repro-01-a-chat-b-before-push.png',
    fullPage: true,
  });

  // Tap push → B|A
  await simulateNotificationTap(page, {
    recipientUserId: acct2.userId,
    peerProfileId: acct1.userId,
  });

  await expectFocusedUserId(page, acct2.userId);
  await waitForChatInput(page);

  const peerAfterPush = account1.displayName ?? acct1.username;
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const headerShowsSender = await page
          .getByText(peerAfterPush)
          .first()
          .isVisible()
          .catch(() => false);
        const headerStillStale = await page
          .getByText(peerBeforePush)
          .first()
          .isVisible()
          .catch(() => false);
        return headerShowsSender && !headerStillStale;
      },
      { timeout: E2E_TIMEOUT.message },
    )
    .toBe(true);

  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const hasLegit = await page.getByText(MSG_A).isVisible().catch(() => false);
        const hasB = await page.getByText(MSG_B).isVisible().catch(() => false);
        return hasLegit && hasB;
      },
      { timeout: E2E_TIMEOUT.message },
    )
    .toBe(true);

  await page.screenshot({
    path: '/opt/cursor/artifacts/screenshots/repro-02-b-chat-a-after-push.png',
    fullPage: true,
  });

  const poisonByVisible = await page
    .getByText(POISON_BY)
    .isVisible()
    .catch(() => false);

  console.log('=== RIPRODUZIONE PUSH TAP ===');
  console.log(`Focus: account B (${acct2.userId})`);
  console.log(`Header peer dopo push: ${peerAfterPush}`);
  console.log(`MSG_A visibile: ${await page.getByText(MSG_A).isVisible()}`);
  console.log(`MSG_B visibile: ${await page.getByText(MSG_B).isVisible()}`);
  console.log(`POISON_BY visibile: ${poisonByVisible}`);
  console.log(formatDiagnosticLogsFooter(diagLogs));

  expect(poisonByVisible, 'INV-PUSH-MSG-3: poison B|Y non deve apparire su B|A').toBe(
    false,
  );
});
