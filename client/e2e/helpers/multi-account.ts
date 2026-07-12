// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Page } from '@playwright/test';

import {
  enableFlutterAccessibility,
  readSavedAccountsManifest,
  type ManifestEntry,
} from './flutter-a11y';
import { E2E_POLL, E2E_TIMEOUT } from './timeouts';

export const BASE_URL =
  process.env.ALFRED_BASE_URL ?? 'https://alfred-im.github.io/alfred-im/';

export const ACCOUNT1 = {
  email:
    process.env.ALFRED_ACCOUNT1_EMAIL ??
    'agadriel.sexpositive+alfredagent1@gmail.com',
  password: process.env.ALFRED_ACCOUNT1_PASSWORD ?? 'AlfredAgentDbg1!',
  username: process.env.ALFRED_ACCOUNT1_USERNAME ?? 'alfredagent1',
};

export const ACCOUNT2 = {
  email:
    process.env.ALFRED_ACCOUNT2_EMAIL ??
    'agadriel.sexpositive+alfredagent2@gmail.com',
  password: process.env.ALFRED_ACCOUNT2_PASSWORD ?? 'AlfredAgentDbg2!',
  username: process.env.ALFRED_ACCOUNT2_USERNAME ?? 'alfredagent2',
};

/** Attende che Flutter esponga il form di login (poll a11y, niente sleep da 8s). */
export async function waitForAuthForm(page: Page) {
  const email = page.getByRole('textbox', { name: 'Email' });
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        return email.isVisible();
      },
      { timeout: E2E_TIMEOUT.boot, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

/** Shell autenticata: overlay auth chiuso (niente Email) + inbox con FAB. */
export async function waitForLoggedInShell(page: Page) {
  const fab = page.getByRole('button', { name: 'Nuovo messaggio' });
  const emailField = page.getByRole('textbox', { name: 'Email' });
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const overlayClosed = !(await emailField.isVisible().catch(() => false));
        const noPlaceholder = !(await page
          .getByText('Nessun account aperto')
          .isVisible()
          .catch(() => false));
        const fabVisible = await fab.isVisible().catch(() => false);
        return overlayClosed && noPlaceholder && fabVisible;
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

export async function clearAppData(page: Page) {
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'domcontentloaded', timeout: E2E_TIMEOUT.boot });
  await waitForAuthForm(page);
}

export async function openAccountDrawer(page: Page) {
  await page
    .locator('flt-semantics[role="button"]')
    .first()
    .click({ timeout: E2E_TIMEOUT.ui });
  await expect(page.getByText('Aggiungi account')).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
}

export async function closeDrawerIfOpen(page: Page) {
  const drawerMarker = page.getByText('Aggiungi account');
  if (await drawerMarker.isVisible().catch(() => false)) {
    await page.keyboard.press('Escape');
    await expect(drawerMarker).not.toBeVisible({ timeout: 2_000 });
  }
}

export async function clickAggiungiAccount(page: Page) {
  await openAccountDrawer(page);
  await page.getByText('Aggiungi account').click();
}

export async function loginInAuthForm(
  page: Page,
  email: string,
  password: string,
  options?: { minAccounts?: number },
) {
  const emailField = page.getByRole('textbox', { name: 'Email' });
  const passwordField = page.getByRole('textbox', { name: 'Password' });
  await emailField.click();
  await emailField.fill(email);
  await passwordField.click();
  await passwordField.fill(password);
  await expect(passwordField).toHaveValue(password, { timeout: 3_000 });
  await page.getByRole('button', { name: 'Accedi' }).click();

  await waitForLoggedInShell(page);

  const minAccounts = options?.minAccounts ?? 1;
  await expect
    .poll(
      async () => {
        const manifest = await readSavedAccountsManifest(page);
        return (
          manifest != null &&
          manifest.length >= minAccounts &&
          manifest.every((e) => (e.refreshToken?.length ?? 0) > 10)
        );
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

export async function expectLoggedInShell(page: Page) {
  await waitForLoggedInShell(page);
}

/** Con 2+ account in RAM la sidebar mobile mostra «Altri account». */
export async function expectMultiAccountList(page: Page, visible: boolean) {
  await openAccountDrawer(page);
  const section = page.getByText('Altri account');
  if (visible) {
    await expect(section).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  } else {
    await expect(section).not.toBeVisible({ timeout: 2_000 });
  }
  await closeDrawerIfOpen(page);
}

export function expectManifestCount(
  manifest: { userId: string; refreshToken: string }[] | null,
  count: number,
) {
  expect(manifest, 'manifest assente').not.toBeNull();
  expect(manifest!.length, `manifest: ${JSON.stringify(manifest)}`).toBe(count);
  if (count >= 2) {
    const tokens = manifest!.map((e) => e.refreshToken);
    expect(
      new Set(tokens).size,
      `refreshToken duplicati: ${JSON.stringify(manifest)}`,
    ).toBe(count);
  }
}

export function manifestEntryForUsername(
  manifest: ManifestEntry[],
  username: string,
): ManifestEntry {
  const entry = manifest.find((e) => e.username === username);
  expect(
    entry,
    `manifest senza username ${username}: ${JSON.stringify(manifest)}`,
  ).toBeDefined();
  return entry!;
}

export type TwoAccountSetup = {
  account1: ManifestEntry;
  account2: ManifestEntry;
};

/** Login account 1, aggiunge account 2; al termine il focus è su account 2. */
export async function setupTwoAccounts(page: Page): Promise<TwoAccountSetup> {
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: E2E_TIMEOUT.boot });
  await clearAppData(page);
  await loginInAuthForm(page, ACCOUNT1.email, ACCOUNT1.password);
  expectManifestCount(await readSavedAccountsManifest(page), 1);
  await expectMultiAccountList(page, false);

  await clickAggiungiAccount(page);
  await waitForAuthForm(page);
  await loginInAuthForm(page, ACCOUNT2.email, ACCOUNT2.password, {
    minAccounts: 2,
  });
  expectManifestCount(await readSavedAccountsManifest(page), 2);
  await expectMultiAccountList(page, true);

  const manifest = (await readSavedAccountsManifest(page))!;
  return {
    account1: manifestEntryForUsername(manifest, ACCOUNT1.username),
    account2: manifestEntryForUsername(manifest, ACCOUNT2.username),
  };
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function drawerAccountButton(page: Page, displayName: string) {
  const drawer = page.getByRole('group').filter({ hasText: 'Altri account' });
  return drawer.getByRole('button', {
    name: new RegExp(escapeRegExp(displayName)),
  });
}

function activeAccountGroup(page: Page, displayName: string) {
  return page.getByRole('group', {
    name: new RegExp(escapeRegExp(displayName)),
  });
}

async function expectFocusedUserId(page: Page, userId: string) {
  await expect
    .poll(
      async () =>
        page.evaluate((id) => {
          const raw = localStorage.getItem('flutter.alfred_focus_user_id');
          if (!raw) return false;
          let value: unknown = raw;
          while (typeof value === 'string' && value.startsWith('"')) {
            value = JSON.parse(value);
          }
          return value === id;
        }, userId),
      { timeout: E2E_TIMEOUT.ui },
    )
    .toBe(true);
}

function inboxPeerButton(page: Page, displayName: string) {
  return page
    .getByRole('button', { name: new RegExp(escapeRegExp(displayName)) })
    .filter({ hasNotText: /@/ });
}

/**
 * Cambia focus account dal drawer mobile.
 * Clic solo nel drawer — non sulla riga inbox (stesso nome del destinatario).
 */
export async function switchToAccountByDisplayName(
  page: Page,
  displayName: string,
  userId?: string,
) {
  await openAccountDrawer(page);

  const otherAccount = drawerAccountButton(page, displayName);
  if ((await otherAccount.count()) > 0) {
    await otherAccount.first().click({ timeout: E2E_TIMEOUT.ui });
    await closeDrawerIfOpen(page);
  } else {
    await expect(
      activeAccountGroup(page, displayName).first(),
      `account «${displayName}» non trovato nel drawer`,
    ).toBeVisible({ timeout: 3_000 });
    await closeDrawerIfOpen(page);
  }

  if (userId) {
    await expectFocusedUserId(page, userId);
  }

  await waitForLoggedInShell(page);
}

export async function waitForChatInput(page: Page) {
  const field = page
    .getByRole('textbox', { name: /Scrivi un messaggio/i })
    .or(page.locator('flt-semantics[role="textbox"]').last());
  await expect(field).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  return field;
}

export async function composeNewMessage(page: Page, peerUsername: string) {
  await page.getByRole('button', { name: 'Nuovo messaggio' }).click({
    timeout: E2E_TIMEOUT.ui,
  });
  const address = page.getByRole('textbox', { name: 'Indirizzo' });
  await address.fill(peerUsername);
  await page.getByRole('button', { name: 'Continua' }).click();
  await waitForChatInput(page);
}

export async function sendChatMessage(page: Page, body: string) {
  await expect(
    page.getByText(/cannot message yourself|messaggio a te stesso/i),
  ).not.toBeVisible({ timeout: 2_000 });
  const field = await waitForChatInput(page);
  await field.click();
  await field.pressSequentially(body, { delay: 15 });
  await field.press('Enter');
  await expect(
    page.getByText(/cannot message yourself|PostgrestException/i),
  ).not.toBeVisible({ timeout: 3_000 });
  await expect(page.getByText(body)).toBeVisible({
    timeout: E2E_TIMEOUT.message,
  });
}

export async function openPeerInInbox(page: Page, displayName: string) {
  await expect(page.getByRole('button', { name: 'Nuovo messaggio' })).toBeVisible(
    { timeout: E2E_TIMEOUT.ui },
  );
  const row = inboxPeerButton(page, displayName);
  await expect(
    row.first(),
    `inbox senza conversazione con ${displayName}`,
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await row.first().click();
  await waitForChatInput(page);
}

export async function backToInboxFromChat(page: Page) {
  await page.locator('flt-semantics[role="button"]').first().click();
  await expect(page.getByRole('button', { name: 'Nuovo messaggio' })).toBeVisible(
    { timeout: E2E_TIMEOUT.ui },
  );
}

export async function expectChatContains(
  page: Page,
  bodies: string[],
  options?: { absent?: string[] },
) {
  for (const body of bodies) {
    await expect(page.getByText(body)).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
  }
  for (const body of options?.absent ?? []) {
    await expect(page.getByText(body)).not.toBeVisible({ timeout: 2_000 });
  }
}

/**
 * Dopo un invio dall'altro account: cambia focus, apre la chat col mittente,
 * verifica il messaggio in UI. Nessun reload — se l'app è rotta, fallisce.
 */
export async function expectReceivedMessageOnAccount(
  page: Page,
  recipient: { displayName: string; userId: string },
  sender: { displayName: string },
  body: string,
) {
  await switchToAccountByDisplayName(
    page,
    recipient.displayName,
    recipient.userId,
  );
  await openPeerInInbox(page, sender.displayName);
  await expectChatContains(page, [body]);
}
