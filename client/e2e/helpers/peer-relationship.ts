// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { execSync } from 'node:child_process';

import { expect, type Page } from '@playwright/test';

import { enableFlutterAccessibility } from './flutter-a11y';
import { createLocalConfirmedUser } from './local-auth';
import {
  addReceptionAllowlist,
  configureLocalChatMediaBucket,
  sendMessageToProfile,
} from './local-push-setup';
import { loginSupabase } from './supabase-api';
import { E2E_TIMEOUT } from './timeouts';

export type LocalPeerRelationshipPair = {
  acct1: Awaited<ReturnType<typeof createLocalConfirmedUser>>;
  acct2: Awaited<ReturnType<typeof createLocalConfirmedUser>>;
  session1: Awaited<ReturnType<typeof loginSupabase>>;
  session2: Awaited<ReturnType<typeof loginSupabase>>;
  seedMessage: string;
};

function runPsqlScalar(sql: string): string {
  return execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -t -A -c ${JSON.stringify(sql)}`,
    { encoding: 'utf8' },
  ).trim();
}

/** Rimuove rubrica e allow list viewer→peer (setup pulito per insert da UI). */
export function clearPeerRelationshipInDb(
  focusUserId: string,
  peerProfileId: string,
): void {
  const sql =
    `DELETE FROM public.contacts ` +
    `WHERE archive_user_id = '${focusUserId}' AND linked_profile_id = '${peerProfileId}'; ` +
    `DELETE FROM public.reception_allowlist ` +
    `WHERE archive_user_id = '${focusUserId}' AND allowed_profile_id = '${peerProfileId}';`;
  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );
}

export function countContactsInDb(
  focusUserId: string,
  peerProfileId: string,
): number {
  const sql =
    `SELECT count(*)::int FROM public.contacts ` +
    `WHERE archive_user_id = '${focusUserId}' AND linked_profile_id = '${peerProfileId}' ` +
    `AND protocol = 'internal';`;
  return Number.parseInt(runPsqlScalar(sql), 10);
}

export function countAllowlistInDb(
  focusUserId: string,
  peerProfileId: string,
): number {
  const sql =
    `SELECT count(*)::int FROM public.reception_allowlist ` +
    `WHERE archive_user_id = '${focusUserId}' AND allowed_profile_id = '${peerProfileId}';`;
  return Number.parseInt(runPsqlScalar(sql), 10);
}

export async function expectContactInDb(
  focusUserId: string,
  peerProfileId: string,
): Promise<void> {
  await expect
    .poll(() => countContactsInDb(focusUserId, peerProfileId), {
      timeout: E2E_TIMEOUT.db,
    })
    .toBe(1);
}

export async function expectAllowlistInDb(
  focusUserId: string,
  peerProfileId: string,
): Promise<void> {
  await expect
    .poll(() => countAllowlistInDb(focusUserId, peerProfileId), {
      timeout: E2E_TIMEOUT.db,
    })
    .toBe(1);
}

export async function expectContactAbsentInDb(
  focusUserId: string,
  peerProfileId: string,
): Promise<void> {
  await expect
    .poll(() => countContactsInDb(focusUserId, peerProfileId), {
      timeout: E2E_TIMEOUT.db,
    })
    .toBe(0);
}

/** Inserisce riga rubrica interna viewer→peer (setup «già in rubrica»). */
export function insertContactInDb(
  focusUserId: string,
  peerProfileId: string,
  displayName: string,
): void {
  const safeName = displayName.replace(/'/g, "''");
  const sql =
    `INSERT INTO public.contacts (archive_user_id, protocol, linked_profile_id, display_name) ` +
    `VALUES ('${focusUserId}', 'internal', '${peerProfileId}', '${safeName}') ` +
    `ON CONFLICT DO NOTHING;`;
  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );
}

/**
 * Due utenti con conversazione in inbox; acct1 ha già acct2 in rubrica **e** allow list.
 * Riproduce il telefono: relazione già presente in DB, UI deve rifletterla dopo switch.
 */
export async function prepareLocalPeerWithRubricaAndConsent(
  label1: string,
  label2: string,
): Promise<LocalPeerRelationshipPair> {
  configureLocalChatMediaBucket();
  const acct1 = await createLocalConfirmedUser(label1);
  const acct2 = await createLocalConfirmedUser(label2);

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

  insertContactInDb(acct1.userId, acct2.userId, `E2E ${label2}`);

  const stamp = Date.now();
  const seedMessage = `rubrica-consent-${stamp}`;
  await sendMessageToProfile({
    senderAccessToken: session1.accessToken,
    recipientProfileId: acct2.userId,
    body: seedMessage,
    clientMessageId: `rubrica-consent-${stamp}`,
  });

  expect(countAllowlistInDb(acct1.userId, acct2.userId)).toBe(1);
  expect(countContactsInDb(acct1.userId, acct2.userId)).toBe(1);

  return { acct1, acct2, session1, session2, seedMessage };
}

export async function expectAllowlistAbsentInDb(
  focusUserId: string,
  peerProfileId: string,
): Promise<void> {
  await expect
    .poll(() => countAllowlistInDb(focusUserId, peerProfileId), {
      timeout: E2E_TIMEOUT.db,
    })
    .toBe(0);
}

/**
 * Due utenti con conversazione in inbox; acct1 ha già acct2 in allow list (profilo consentito).
 * Solo rubrica eventualmente pulita — le azioni consenso partono da «già consentito».
 */
export async function prepareLocalConsentedPeerPair(
  label1: string,
  label2: string,
): Promise<LocalPeerRelationshipPair> {
  configureLocalChatMediaBucket();
  const acct1 = await createLocalConfirmedUser(label1);
  const acct2 = await createLocalConfirmedUser(label2);

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

  const stamp = Date.now();
  const seedMessage = `consent-toggle-${stamp}`;
  await sendMessageToProfile({
    senderAccessToken: session1.accessToken,
    recipientProfileId: acct2.userId,
    body: seedMessage,
    clientMessageId: `consent-toggle-${stamp}`,
  });

  // Rubrica pulita; allow list acct1→acct2 resta (profilo già consentito).
  const sql =
    `DELETE FROM public.contacts ` +
    `WHERE archive_user_id = '${acct1.userId}' AND linked_profile_id = '${acct2.userId}';`;
  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );

  expect(countAllowlistInDb(acct1.userId, acct2.userId)).toBe(1);
  expect(countContactsInDb(acct1.userId, acct2.userId)).toBe(0);

  return { acct1, acct2, session1, session2, seedMessage };
}

/**
 * Due utenti con conversazione già in inbox su acct1, poi rubrica/allow acct1→acct2
 * rimossi così le azioni UI devono ricreare le righe.
 */
export async function prepareLocalPeerRelationshipPair(
  label1: string,
  label2: string,
): Promise<LocalPeerRelationshipPair> {
  configureLocalChatMediaBucket();
  const acct1 = await createLocalConfirmedUser(label1);
  const acct2 = await createLocalConfirmedUser(label2);

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

  const stamp = Date.now();
  const seedMessage = `peer-rel-${stamp}`;
  await sendMessageToProfile({
    senderAccessToken: session1.accessToken,
    recipientProfileId: acct2.userId,
    body: seedMessage,
    clientMessageId: `peer-rel-${stamp}`,
  });

  clearPeerRelationshipInDb(acct1.userId, acct2.userId);

  expect(countContactsInDb(acct1.userId, acct2.userId)).toBe(0);
  expect(countAllowlistInDb(acct1.userId, acct2.userId)).toBe(0);

  return { acct1, acct2, session1, session2, seedMessage };
}

export async function openChatHeaderMenu(page: Page): Promise<void> {
  await enableFlutterAccessibility(page);
  const menu = page.getByRole('button', { name: 'Altre azioni', exact: true });
  await expect(menu).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await menu.click({ timeout: E2E_TIMEOUT.ui });
}

export async function selectChatHeaderMenuItem(
  page: Page,
  label: string,
): Promise<void> {
  await enableFlutterAccessibility(page);
  const item = page.getByRole('menuitem', { name: label, exact: true });
  await expect(item).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await item.click({ timeout: E2E_TIMEOUT.ui });
  await page.waitForTimeout(500);
}

export async function closeChatHeaderMenu(page: Page): Promise<void> {
  await enableFlutterAccessibility(page);
  if (!(await page.getByRole('menuitem').first().isVisible().catch(() => false))) {
    return;
  }
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  if (await page.getByRole('menuitem').first().isVisible().catch(() => false)) {
    const viewport = page.viewportSize() ?? { width: 390, height: 844 };
    await page.mouse.click(viewport.width / 2, viewport.height - 80);
    await page.waitForTimeout(300);
  }
}

export async function openPeerProfileFromChatHeader(page: Page): Promise<void> {
  await closeChatHeaderMenu(page);
  await enableFlutterAccessibility(page);
  await page
    .getByRole('button', { name: 'Apri profilo', exact: true })
    .click({ timeout: E2E_TIMEOUT.ui });
}

export async function expectNoRelationshipError(page: Page): Promise<void> {
  await expect(
    page.getByText(
      /PostgrestException|42501|23505|duplicate key|Sessione non disponibile/i,
    ),
  ).not.toBeVisible({ timeout: 3_000 });
}
