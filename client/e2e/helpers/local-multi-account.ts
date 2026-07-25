// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { type Page } from '@playwright/test';

import { readSavedAccountsManifest } from './flutter-a11y';
import {
  createLocalConfirmedUser,
  type LocalE2eUser,
} from './local-auth';
import { addReceptionAllowlist, configureLocalChatMediaBucket } from './local-push-setup';
import {
  BASE_URL,
  clearAppData,
  clickAggiungiAccount,
  expectManifestCount,
  expectMultiAccountList,
  loginInAuthForm,
  manifestEntryForUsername,
  type TwoAccountSetup,
  waitForAuthForm,
} from './multi-account';
import { loginSupabase } from './supabase-api';
import { E2E_TIMEOUT } from './timeouts';

export type LocalMessagingPair = {
  acct1: LocalE2eUser;
  acct2: LocalE2eUser;
  session1: Awaited<ReturnType<typeof loginSupabase>>;
  session2: Awaited<ReturnType<typeof loginSupabase>>;
};

/** Due utenti locali confermati + allowlist reciproca (messaggistica interna). */
export async function prepareLocalMessagingPair(
  label1: string,
  label2: string,
): Promise<LocalMessagingPair> {
  configureLocalChatMediaBucket();
  const acct1 = await createLocalConfirmedUser(label1);
  const acct2 = await createLocalConfirmedUser(label2);

  const session1 = await loginSupabase(acct1.email, acct1.password);
  const session2 = await loginSupabase(acct2.email, acct2.password);

  await addReceptionAllowlist({
    ownerUserId: acct1.userId,
    allowedProfileId: acct2.userId,
    ownerAccessToken: session1.accessToken,
  });
  await addReceptionAllowlist({
    ownerUserId: acct2.userId,
    allowedProfileId: acct1.userId,
    ownerAccessToken: session2.accessToken,
  });

  return { acct1, acct2, session1, session2 };
}

/** Login account 1, aggiunge account 2; al termine il focus è su account 2. */
export async function setupTwoLocalAccounts(
  page: Page,
  acct1: LocalE2eUser,
  acct2: LocalE2eUser,
): Promise<TwoAccountSetup> {
  await clearAppData(page);
  await loginInAuthForm(page, acct1.email, acct1.password);
  expectManifestCount(await readSavedAccountsManifest(page), 1);
  await expectMultiAccountList(page, false);

  await clickAggiungiAccount(page);
  await waitForAuthForm(page);
  await loginInAuthForm(page, acct2.email, acct2.password, {
    minAccounts: 2,
  });
  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  const manifest = (await readSavedAccountsManifest(page))!;
  return {
    account1: manifestEntryForUsername(manifest, acct1.username),
    account2: manifestEntryForUsername(manifest, acct2.username),
  };
}
