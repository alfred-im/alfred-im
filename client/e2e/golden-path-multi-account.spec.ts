// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Golden path — login UI, messaggistica, switch account, foto, spunte (backend).
 *
 * Percorso:
 * 1. Login account 1
 * 2. Aggiungi account 2
 * 3. Apri account 1 → nuova conversazione con 2 → invia testo
 * 4. Esci → account 2 → chat con 1 → assert testo
 * 5. Invia foto
 * 6. Percorso a ritroso (account 1) → assert foto + read_at (spunta blu backend)
 */
import { test, expect } from '@playwright/test';

import {
  expectImagePersistedBothSides,
  expectMessagePersistedBothSides,
  waitForSenderReadAt,
  type AccountCredentials,
} from './helpers/backend-assertions';
import { expectChatHasPhoto, sendPhotoFromGallery } from './helpers/chat-media';
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
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({ viewport: { width: 390, height: 844 } });
test.setTimeout(180_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'richiede stack Supabase locale');
});

test('golden path: login → testo → switch → foto → spunta blu (UI + backend)', async ({
  page,
}) => {
  const errors = attachPageErrorCollector(page);
  const stamp = Date.now();
  const textBody = `golden-text-${stamp}`;
  const photoCaption = `golden-photo-${stamp}`;

  const { acct1, acct2 } = await prepareLocalMessagingPair('gp1', 'gp2');

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
  const display1 = account1.displayName ?? `E2E gp1`;
  const display2 = account2.displayName ?? `E2E gp2`;

  // --- Apri account 1, conversazione con 2, invio testo ---
  await switchToAccountByDisplayName(page, display1, account1.userId);
  await composeNewMessage(page, acct2.username);
  await sendChatMessage(page, textBody);
  await backToInboxFromChat(page);

  await expectMessagePersistedBothSides({
    body: textBody,
    sender: cred1,
    recipient: cred2,
  });

  // --- Account 2: ricezione testo ---
  await switchToAccountByDisplayName(page, display2, account2.userId);
  await openPeerInInbox(page, display1);
  await expectChatContains(page, [textBody]);

  // Apertura chat → mark_peer_read → spunta blu su copia mittente (account 1)
  await waitForSenderReadAt({
    sender: cred1,
    peerUserId: cred2.userId,
    body: textBody,
  });

  // --- Invio foto da account 2 ---
  await sendPhotoFromGallery(page, { caption: photoCaption });
  await expectImagePersistedBothSides({
    sender: cred2,
    recipient: cred1,
    caption: photoCaption,
  });
  await backToInboxFromChat(page);

  // --- Percorso a ritroso: account 1 ---
  await switchToAccountByDisplayName(page, display1, account1.userId);
  await openPeerInInbox(page, display2);
  await expectChatContains(page, [textBody]);
  await expectChatHasPhoto(page);

  // Backend: foto letta → read_at su copia mittente account 2 (spunta blu)
  await waitForSenderReadAt({
    sender: cred2,
    peerUserId: cred1.userId,
    contentType: 'image',
  });

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
