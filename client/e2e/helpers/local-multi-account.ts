// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { type Page } from '@playwright/test';

import { readSavedAccountsManifest, type ManifestEntry } from './flutter-a11y';
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
    focusUserId: acct1.userId,
    allowedProfileId: acct2.userId,
    focusAccessToken: session1.accessToken,
  });
  await addReceptionAllowlist({
    focusUserId: acct2.userId,
    allowedProfileId: acct1.userId,
    focusAccessToken: session2.accessToken,
  });

  return { acct1, acct2, session1, session2 };
}

export type LocalFiveAccountManifest = {
  users: [LocalE2eUser, LocalE2eUser, LocalE2eUser, LocalE2eUser];
  group: LocalE2eUser;
};

/** 4 user + 1 gruppo — stesso setup dell'utente in produzione. */
export async function prepareLocalFiveAccountManifest(
  stamp: string,
): Promise<LocalFiveAccountManifest> {
  configureLocalChatMediaBucket();
  const users = await Promise.all([
    createLocalConfirmedUser(`u1${stamp}`),
    createLocalConfirmedUser(`u2${stamp}`),
    createLocalConfirmedUser(`u3${stamp}`),
    createLocalConfirmedUser(`u4${stamp}`),
  ]);
  const group = await createLocalConfirmedUser(`grp${stamp}`, {
    profileKind: 'group',
  });

  const session1 = await loginSupabase(users[0].email, users[0].password);
  for (const other of [users[1], users[2], users[3], group]) {
    await addReceptionAllowlist({
      focusUserId: users[0].userId,
      allowedProfileId: other.userId,
      focusAccessToken: session1.accessToken,
    });
    const sessionOther = await loginSupabase(other.email, other.password);
    await addReceptionAllowlist({
      focusUserId: other.userId,
      allowedProfileId: users[0].userId,
      focusAccessToken: sessionOther.accessToken,
    });
  }
  const session2 = await loginSupabase(users[1].email, users[1].password);
  await addReceptionAllowlist({
    focusUserId: users[1].userId,
    allowedProfileId: users[0].userId,
    focusAccessToken: session2.accessToken,
  });
  await addReceptionAllowlist({
    focusUserId: users[0].userId,
    allowedProfileId: users[1].userId,
    focusAccessToken: session1.accessToken,
  });

  return { users: users as LocalFiveAccountManifest['users'], group };
}

/** Login 4 user + gruppo; focus finale sul gruppo (come ultimo aggiunto). */
export async function setupFiveLocalAccounts(
  page: Page,
  manifest: LocalFiveAccountManifest,
): Promise<ManifestEntry[]> {
  const all = [...manifest.users, manifest.group];
  await clearAppData(page);
  await loginInAuthForm(page, all[0].email, all[0].password);
  for (let i = 1; i < all.length; i++) {
    await clickAggiungiAccount(page);
    await waitForAuthForm(page);
    await loginInAuthForm(page, all[i].email, all[i].password, {
      minAccounts: i + 1,
    });
  }
  expectManifestCount(await readSavedAccountsManifest(page), 5);
  return (await readSavedAccountsManifest(page))!;
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
