// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import type { Page } from '@playwright/test';

import { enableFlutterAccessibility } from './flutter-a11y';
import type { LocalE2eUser } from './local-auth';
import { addReceptionAllowlist, sendMessageToProfile } from './local-push-setup';
import {
  clearPeerRelationshipInDb,
  insertContactInDb,
} from './peer-relationship';
import { loginSupabase } from './supabase-api';
import { waitForAppBoot, waitForLoggedInShell } from './multi-account';
import { snakeStep } from './snake-log';
import { E2E_TIMEOUT } from './timeouts';

/** Dopo mutazioni SQL la UI Flutter può restare stale — F5 sul manifest. */
export async function resyncSnakeShell(page: Page): Promise<void> {
  await page.reload({
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await waitForAppBoot(page);
  await waitForLoggedInShell(page);
  await enableFlutterAccessibility(page);
}

/** Allowlist bidirezionale — messaggistica possibile. */
export async function transitionMessagingReady(
  acct1: LocalE2eUser,
  acct2: LocalE2eUser,
): Promise<void> {
  snakeStep('transition.messaging_ready');
  const session1 = await loginSupabase(acct1.email, acct1.password);
  const session2 = await loginSupabase(acct2.email, acct2.password);
  await addReceptionAllowlist({
    recipientUserId: acct1.userId,
    allowedProfileId: acct2.userId,
    recipientAccessToken: session1.accessToken,
  });
  await addReceptionAllowlist({
    recipientUserId: acct2.userId,
    allowedProfileId: acct1.userId,
    recipientAccessToken: session2.accessToken,
  });
}

/** Peer pulito su focus→peer + messaggio seed in inbox. */
export async function transitionPeerCanAdd(
  acct1: LocalE2eUser,
  acct2: LocalE2eUser,
  seedMessage: string,
  clientMessageId: string,
): Promise<void> {
  snakeStep('transition.peer_can_add');
  await transitionMessagingReady(acct1, acct2);
  const session1 = await loginSupabase(acct1.email, acct1.password);
  await sendMessageToProfile({
    senderAccessToken: session1.accessToken,
    recipientProfileId: acct2.userId,
    body: seedMessage,
    clientMessageId,
  });
  clearPeerRelationshipInDb(acct1.userId, acct2.userId);
}

/** Rubrica + consenso già presenti (stato telefono «già collegato»). */
export async function transitionPeerEstablished(
  acct1: LocalE2eUser,
  acct2: LocalE2eUser,
  seedMessage: string,
  clientMessageId: string,
): Promise<void> {
  snakeStep('transition.peer_established');
  await transitionMessagingReady(acct1, acct2);
  insertContactInDb(acct1.userId, acct2.userId, acct2.username);
  const session1 = await loginSupabase(acct1.email, acct1.password);
  await sendMessageToProfile({
    senderAccessToken: session1.accessToken,
    recipientProfileId: acct2.userId,
    body: seedMessage,
    clientMessageId,
  });
}
