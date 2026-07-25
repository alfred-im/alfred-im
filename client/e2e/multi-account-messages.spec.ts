// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Multi-account mobile — messaggistica (stack locale o live).
 *
 * Stack locale (default `bash scripts/test.sh e2e-multi`):
 * login UI → testo → switch → foto → read_at backend.
 *
 * Live (override esplicito ALFRED_BASE_URL=Pages): scambio testo bidirezionale + DB.
 */
import { test, expect } from '@playwright/test';

import {
  expectImagePersistedBothSides,
  expectMessagePersistedBothSides as expectMessagePersistedBothSidesBackend,
  waitForSenderReadAt,
  type AccountCredentials,
} from './helpers/backend-assertions';
import { expectChatHasPhoto, sendPhotoFromGallery } from './helpers/chat-media';
import {
  attachDiagnosticLogCollector,
  dumpDiagnosticLogsOnFailure,
} from './helpers/diagnostic-logs';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  prepareLocalMessagingPair,
  setupTwoLocalAccounts,
} from './helpers/local-multi-account';
import {
  ACCOUNT1,
  ACCOUNT2,
  backToInboxFromChat,
  composeNewMessage,
  expectChatContains,
  expectReceivedMessageOnAccount,
  openPeerInInbox,
  sendChatMessage,
  setupTwoAccounts,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import { attachPageErrorCollector } from './helpers/page-errors';
import {
  expectMessagePersistedBothSides,
  listPeerMessages,
  loginSupabase,
  waitForMessageInDb,
} from './helpers/supabase-api';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(180_000);

let diagLogs: string[] = [];

test.beforeEach(({ page }) => {
  diagLogs = attachDiagnosticLogCollector(page);
});

test.afterEach(({}, testInfo) => {
  dumpDiagnosticLogsOnFailure(diagLogs, testInfo);
});

test('multi-account mobile: testo, foto, switch account e spunte in DB (stack locale)', async ({
  page,
}) => {
  test.skip(!isLocalSupabaseStack(), 'richiede stack Supabase locale');

  const errors = attachPageErrorCollector(page);
  const stamp = Date.now();
  const textBody = `e2e-text-${stamp}`;
  const photoCaption = `e2e-photo-${stamp}`;

  const { acct1, acct2 } = await prepareLocalMessagingPair('ma1', 'ma2');

  const cred1: AccountCredentials = {
    email: acct1.email,
    password: acct1.password,
    userId: acct1.userId,
  };
  const cred2: AccountCredentials = {
    email: acct2.email,
    password: acct2.password,
    userId: acct2.userId,
  };

  const { account1, account2 } = await setupTwoLocalAccounts(page, acct1, acct2);
  const display1 = account1.displayName ?? `E2E ma1`;
  const display2 = account2.displayName ?? `E2E ma2`;

  await switchToAccountByDisplayName(page, display1, account1.userId);
  await composeNewMessage(page, acct2.username);
  await sendChatMessage(page, textBody);
  await backToInboxFromChat(page);

  await expectMessagePersistedBothSidesBackend({
    body: textBody,
    sender: cred1,
    recipient: cred2,
  });

  await switchToAccountByDisplayName(page, display2, account2.userId);
  await openPeerInInbox(page, display1);
  await expectChatContains(page, [textBody]);

  await waitForSenderReadAt({
    sender: cred1,
    peerUserId: cred2.userId,
    body: textBody,
  });

  await sendPhotoFromGallery(page, { caption: photoCaption });
  await expectImagePersistedBothSides({
    sender: cred2,
    recipient: cred1,
    caption: photoCaption,
  });
  await backToInboxFromChat(page);

  await switchToAccountByDisplayName(page, display1, account1.userId);
  await openPeerInInbox(page, display2);
  await expectChatContains(page, [textBody]);
  await expectChatHasPhoto(page);

  await waitForSenderReadAt({
    sender: cred2,
    peerUserId: cred1.userId,
    contentType: 'image',
  });

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});

test('multi-account mobile: scambio testo bidirezionale in DB e UI (live)', async ({
  page,
}) => {
  test.skip(
    isLocalSupabaseStack(),
    'su stack locale usa il test testo+foto',
  );

  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  const stamp = Date.now();
  const msgFrom1 = `e2e-a1-${stamp}`;
  const msgFrom2 = `e2e-a2-${stamp}`;

  const { account1, account2 } = await setupTwoAccounts(page);
  const agent1Id = account1.userId;
  const agent2Id = account2.userId;

  await switchToAccountByDisplayName(
    page,
    account1.displayName!,
    agent1Id,
  );
  await openPeerInInbox(page, account2.displayName!);
  await sendChatMessage(page, msgFrom1);
  await backToInboxFromChat(page);

  await expectMessagePersistedBothSides({
    body: msgFrom1,
    senderUserId: agent1Id,
    recipientUserId: agent2Id,
    senderEmail: ACCOUNT1.email,
    senderPassword: ACCOUNT1.password,
    recipientEmail: ACCOUNT2.email,
    recipientPassword: ACCOUNT2.password,
  });

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
