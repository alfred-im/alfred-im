// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Multi-account mobile — messaggistica su stack locale.
 *
 * `bash scripts/test.sh e2e-multi`: login UI → testo → switch → foto → read_at backend.
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
  backToInboxFromChat,
  composeNewMessage,
  expectChatContains,
  openPeerInInbox,
  sendChatMessage,
  switchToAccountByDisplayName,
} from './helpers/multi-account';
import { attachPageErrorCollector } from './helpers/page-errors';

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
