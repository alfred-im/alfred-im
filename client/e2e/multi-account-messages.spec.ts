// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import {
  attachDiagnosticLogCollector,
  dumpDiagnosticLogsOnFailure,
} from './helpers/diagnostic-logs';
import {
  backToInboxFromChat,
  ACCOUNT1,
  ACCOUNT2,
  expectChatContains,
  expectReceivedMessageOnAccount,
  openPeerInInbox,
  sendChatMessage,
  setupTwoAccounts,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import {
  expectMessagePersistedBothSides,
  listPeerMessages,
  loginSupabase,
  waitForMessageInDb,
} from './helpers/supabase-api';

/**
 * Multi-account mobile: invio UI + verifica DB (list_peer_messages) + ricezione UI.
 *
 * Il gate principale è il DB: se il messaggio non è in Postgres, il test fallisce
 * subito — indipendentemente dall’UI Flutter.
 */
test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(90_000);

let diagLogs: string[] = [];

test.beforeEach(({ page }) => {
  diagLogs = attachDiagnosticLogCollector(page);
});

test.afterEach(({}, testInfo) => {
  dumpDiagnosticLogsOnFailure(diagLogs, testInfo);
});

test('multi-account mobile: messaggio in DB e visibile dall’altro account', async ({
  page,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const stamp = Date.now();
  const msgFrom1 = `e2e-a1-${stamp}`;
  const msgFrom2 = `e2e-a2-${stamp}`;

  const { account1, account2 } = await setupTwoAccounts(page);
  const agent1Id = account1.userId;
  const agent2Id = account2.userId;

  // --- Invio da account 1 ---
  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    agent1Id,
  );
  await openPeerInInbox(page, account2.displayName!);
  await sendChatMessage(page, msgFrom1);
  await backToInboxFromChat(page);

  // Gate DB: deve esistere per mittente e destinatario
  await expectMessagePersistedBothSides({
    body: msgFrom1,
    senderUserId: agent1Id,
    recipientUserId: agent2Id,
    senderEmail: ACCOUNT1.email,
    senderPassword: ACCOUNT1.password,
    recipientEmail: ACCOUNT2.email,
    recipientPassword: ACCOUNT2.password,
  });

  // --- Ricezione su account 2: prima cambia account, poi entra in chat ---
  await waitForMessageInDb({
    viewerEmail: ACCOUNT2.email,
    viewerPassword: ACCOUNT2.password,
    peerProfileId: agent1Id,
    body: msgFrom1,
    expectedSenderId: agent1Id,
  });

  await expectReceivedMessageOnAccount(
    page,
    { displayName: account2.displayName!, userId: agent2Id },
    { displayName: account1.displayName! },
    msgFrom1,
  );

  // --- Risposta da account 2 ---
  await sendChatMessage(page, msgFrom2);
  await backToInboxFromChat(page);

  await expectMessagePersistedBothSides({
    body: msgFrom2,
    senderUserId: agent2Id,
    recipientUserId: agent1Id,
    senderEmail: ACCOUNT2.email,
    senderPassword: ACCOUNT2.password,
    recipientEmail: ACCOUNT1.email,
    recipientPassword: ACCOUNT1.password,
  });

  // --- Account 1: cambia account e verifica la risposta in chat ---
  await waitForMessageInDb({
    viewerEmail: ACCOUNT1.email,
    viewerPassword: ACCOUNT1.password,
    peerProfileId: agent2Id,
    body: msgFrom2,
    expectedSenderId: agent2Id,
  });

  await expectReceivedMessageOnAccount(
    page,
    { displayName: account1.displayName!, userId: agent1Id },
    { displayName: account2.displayName! },
    msgFrom2,
  );
  await expectChatContains(page, [msgFrom1, msgFrom2]);

  const asAgent1 = await loginSupabase(ACCOUNT1.email, ACCOUNT1.password);
  const dbAsAgent1 = await listPeerMessages(asAgent1.accessToken, agent2Id);
  expect(dbAsAgent1.map((m) => m.body)).toEqual(
    expect.arrayContaining([msgFrom1, msgFrom2]),
  );

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
