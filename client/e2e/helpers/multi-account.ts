// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Locator, type Page } from '@playwright/test';

import { enableFlutterAccessibility, readSavedAccountsManifest, type ManifestEntry } from './flutter-a11y';
import { expectFocusedUserId } from './focus';
import { E2E_POLL, E2E_TIMEOUT } from './timeouts';

export const BASE_URL =
  process.env.ALFRED_BASE_URL ?? 'http://localhost:8080/';

/** Attende fine splash «Caricamento Alfred» prima di cercare UI. */
export async function waitForAppBoot(page: Page) {
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const loading = await page
          .getByText('Caricamento Alfred')
          .isVisible()
          .catch(() => false);
        return !loading;
      },
      { timeout: E2E_TIMEOUT.boot * 4, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

/** Attende che Flutter esponga il form di login (poll a11y, niente sleep da 8s). */
export async function waitForAuthForm(page: Page) {
  await waitForAppBoot(page);
  const email = page.getByRole('textbox', { name: 'Email' });
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        return email.isVisible();
      },
      { timeout: E2E_TIMEOUT.boot * 2, intervals: [...E2E_POLL] },
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
        const manifest = await readSavedAccountsManifest(page);
        const hasSession =
          manifest != null &&
          manifest.some((e) => (e.refreshToken?.length ?? 0) > 10);
        const fabVisible = await fab.isVisible().catch(() => false);
        const overlayClosed = !(await emailField.isVisible().catch(() => false));
        const noPlaceholder = !(await page
          .getByText('Nessun account aperto')
          .isVisible()
          .catch(() => false));
        return (
          hasSession &&
          noPlaceholder &&
          (fabVisible || overlayClosed)
        );
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

export async function clearAppData(page: Page) {
  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot * 4,
  });
  await page.evaluate(() => localStorage.clear());
  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot * 4,
  });
  await waitForAuthForm(page);
}

/** Trigger drawer account (avatar in header inbox) — semantics «Menu account». */
export function accountDrawerButton(page: Page) {
  return page.getByRole('button', { name: 'Menu account', exact: true });
}

async function clickAccountDrawerTrigger(page: Page) {
  const labeled = accountDrawerButton(page);
  if (await labeled.isVisible().catch(() => false)) {
    await labeled.click({ timeout: E2E_TIMEOUT.ui, force: true });
    return;
  }

  const search = page.getByRole('button', { name: 'Cerca messaggi' });
  await expect(search).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  const box = await search.boundingBox();
  if (!box) {
    throw new Error('Cerca messaggi senza bounding box — impossibile aprire drawer');
  }
  await page.mouse.click(box.x - 36, box.y + box.height / 2);
}

export async function openAccountDrawer(page: Page) {
  await enableFlutterAccessibility(page);
  if (await isDrawerOpen(page)) {
    return;
  }

  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const labeled = await accountDrawerButton(page).isVisible().catch(() => false);
        const search = await page
          .getByRole('button', { name: 'Cerca messaggi' })
          .isVisible()
          .catch(() => false);
        return labeled || search;
      },
      { timeout: E2E_TIMEOUT.ui * 2, intervals: [...E2E_POLL] },
    )
    .toBe(true);

  await clickAccountDrawerTrigger(page);
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole('button', { name: 'Aggiungi account', exact: true }),
  ).toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
}

async function isDrawerOpen(page: Page): Promise<boolean> {
  return page
    .getByRole('button', { name: 'Aggiungi account', exact: true })
    .isVisible()
    .catch(() => false);
}

/** Chiude il drawer senza throw — per poll e switch account in CI. */
export async function tryCloseDrawerIfOpen(page: Page): Promise<boolean> {
  if (!(await isDrawerOpen(page))) {
    return true;
  }

  await enableFlutterAccessibility(page);

  if (await accountDrawerButton(page).isVisible().catch(() => false)) {
    await accountDrawerButton(page).click({ timeout: E2E_TIMEOUT.ui }).catch(() => {});
    if (!(await isDrawerOpen(page))) {
      return true;
    }
  }

  const viewport = page.viewportSize() ?? { width: 390, height: 844 };
  await page.mouse.click(viewport.width - 20, viewport.height / 2);
  if (!(await isDrawerOpen(page))) {
    return true;
  }

  await page.keyboard.press('Escape');
  if (!(await isDrawerOpen(page))) {
    return true;
  }

  const scrim = page.locator(
    'flt-glass-pane, [aria-modal="true"], .drawer-backdrop',
  );
  if ((await scrim.count()) > 0) {
    await scrim
      .first()
      .click({ position: { x: 10, y: 10 }, timeout: 2_000 })
      .catch(() => {});
  }

  return !(await isDrawerOpen(page));
}

export async function closeDrawerIfOpen(page: Page) {
  for (let attempt = 0; attempt < 3; attempt++) {
    if (await tryCloseDrawerIfOpen(page)) {
      return;
    }
    await page.waitForTimeout(300);
  }
  await expect(
    page.getByRole('button', { name: 'Aggiungi account', exact: true }),
  ).not.toBeVisible({
    timeout: E2E_TIMEOUT.ui,
  });
}

/** Inbox mobile pronta: drawer chiuso + FAB nuovo messaggio. */
export async function ensureInboxReady(page: Page) {
  await closeDrawerIfOpen(page);
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole('button', { name: 'Nuovo messaggio' }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}

export async function clickAggiungiAccount(page: Page) {
  await openAccountDrawer(page);
  await page.getByRole('button', { name: 'Aggiungi account', exact: true }).click();
}

/**
 * Flutter web release: `fill()` spesso non aggiorna il semantics layer (password
 * soprattutto al 2° login «Aggiungi account»). Digitazione reale + poll inputValue.
 */
export async function fillFlutterTextField(
  page: Page,
  field: Locator,
  value: string,
) {
  await enableFlutterAccessibility(page);
  await field.click({ timeout: E2E_TIMEOUT.ui });
  await page.waitForTimeout(100);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value, { delay: 15 });
  await expect
    .poll(async () => field.inputValue(), {
      timeout: E2E_TIMEOUT.ui,
      intervals: [...E2E_POLL],
    })
    .toBe(value);
}

export async function loginInAuthForm(
  page: Page,
  email: string,
  password: string,
  options?: { minAccounts?: number },
) {
  await enableFlutterAccessibility(page);
  const emailField = page.getByRole('textbox', { name: 'Email' });
  const passwordField = page.getByRole('textbox', { name: 'Password' });
  await fillFlutterTextField(page, emailField, email);
  await fillFlutterTextField(page, passwordField, password);
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
  await enableFlutterAccessibility(page);
  // Semantics(header: true) → role banner in Flutter web a11y (non getByText).
  const section = page
    .getByRole('banner', { name: 'Altri account', exact: true })
    .or(page.getByRole('heading', { name: 'Altri account', exact: true }))
    .or(page.getByText('Altri account', { exact: true }));
  const aggiungi = page.getByRole('button', {
    name: 'Aggiungi account',
    exact: true,
  });
  await expect(aggiungi).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  if (visible) {
    await expect
      .poll(
        async () => {
          await enableFlutterAccessibility(page);
          return section.isVisible().catch(() => false);
        },
        { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
      )
      .toBe(true);
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

function inboxPeerButton(page: Page, displayName: string) {
  return page
    .getByRole('button', { name: new RegExp(escapeRegExp(displayName)) })
    .filter({ hasNotText: /@/ });
}

/** Inbox account utente (non gruppo): FAB o ricerca messaggi. */
async function isUserInboxShell(page: Page): Promise<boolean> {
  await enableFlutterAccessibility(page);
  if (
    await page
      .getByRole('button', { name: 'Nuovo messaggio' })
      .isVisible()
      .catch(() => false)
  ) {
    return true;
  }
  return page
    .getByRole('button', { name: 'Cerca messaggi' })
    .isVisible()
    .catch(() => false);
}

/** Shell gruppo — niente FAB né ricerca inbox. */
async function isGroupAccountShell(page: Page): Promise<boolean> {
  await enableFlutterAccessibility(page);
  const groupNav = await page
    .getByRole('button', { name: 'Persone consentite' })
    .isVisible()
    .catch(() => false);
  if (!groupNav) {
    return false;
  }
  return !(await isUserInboxShell(page));
}

/** Shell autenticata: inbox utente (FAB/ricerca) oppure chat ripristinata. */
export async function waitForAccountShell(page: Page) {
  const chatInput = chatInputField(page);
  const emailField = page.getByRole('textbox', { name: 'Email' });
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const loading = await page
          .getByText('Caricamento Alfred')
          .isVisible()
          .catch(() => false);
        if (loading) {
          return false;
        }
        if (await isDrawerOpen(page)) {
          await tryCloseDrawerIfOpen(page);
        }
        const overlayClosed = !(await emailField.isVisible().catch(() => false));
        const noPlaceholder = !(await page
          .getByText('Nessun account aperto')
          .isVisible()
          .catch(() => false));
        const userInbox = await isUserInboxShell(page);
        const chatReady = await chatInput.isVisible().catch(() => false);
        const stillOnGroup = await isGroupAccountShell(page);
        return (
          overlayClosed &&
          noPlaceholder &&
          !stillOnGroup &&
          (userInbox || chatReady)
        );
      },
      { timeout: E2E_TIMEOUT.shell, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

/**
 * Cambia focus account dal drawer mobile.
 * Clic solo nel drawer — non sulla riga inbox (stesso nome del destinatario).
 */
async function clickDrawerAccountEntry(
  page: Page,
  byButton: Locator,
  byText: Locator,
) {
  if ((await byButton.count()) > 0) {
    const target = byButton.first();
    await target.scrollIntoViewIfNeeded();
    await target.click({ timeout: E2E_TIMEOUT.ui });
    return;
  }
  await byText.scrollIntoViewIfNeeded();
  await byText.click({ timeout: E2E_TIMEOUT.ui });
}

export async function switchToAccountByDisplayName(
  page: Page,
  displayName: string,
  userId?: string,
) {
  const namePattern = new RegExp(escapeRegExp(displayName));
  const byButton = () =>
    page.getByRole('button', { name: namePattern });
  const byText = () => page.getByText(displayName, { exact: true });

  for (let attempt = 0; attempt < 2; attempt++) {
    await openAccountDrawer(page);
    await enableFlutterAccessibility(page);

    await expect
      .poll(
        async () => {
          await enableFlutterAccessibility(page);
          return (
            (await byButton().count()) > 0 ||
            (await byText().isVisible().catch(() => false))
          );
        },
        { timeout: E2E_TIMEOUT.ui, intervals: [...E2E_POLL] },
      )
      .toBe(true);

    await clickDrawerAccountEntry(page, byButton(), byText());

    await page.waitForTimeout(400);
    await tryCloseDrawerIfOpen(page);

    if (userId) {
      await expectFocusedUserId(page, userId);
    }

    try {
      await waitForAccountShell(page);
      return;
    } catch (error) {
      if (attempt === 1) {
        throw error;
      }
      await page.waitForTimeout(800);
    }
  }
}

function chatInputField(page: Page) {
  return page
    .getByRole('textbox', { name: /Scrivi un messaggio/i })
    .or(page.locator('flt-semantics[role="textbox"]').last());
}

/** Composer pronto: allowlist caricata e peer in lista (SURF-CHAT-017). */
async function isChatComposable(page: Page): Promise<boolean> {
  await enableFlutterAccessibility(page);
  const field = chatInputField(page);
  if (!(await field.isVisible().catch(() => false))) {
    return false;
  }

  const blocked = await page
    .getByText(/non puoi scrivere|allowlist|PostgrestException/i)
    .isVisible()
    .catch(() => false);
  if (blocked) {
    return false;
  }

  const attach = page.getByRole('button', { name: 'Allega' });
  if ((await attach.count()) > 0) {
    if (await attach.first().isEnabled().catch(() => false)) {
      return true;
    }
  }

  if (await field.isEditable().catch(() => false)) {
    return true;
  }

  return field.isEnabled().catch(() => false);
}

export async function waitForChatInput(page: Page) {
  const field = chatInputField(page);
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        return field.isVisible().catch(() => false);
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
    )
    .toBe(true);

  await expect
    .poll(async () => isChatComposable(page), {
      timeout: E2E_TIMEOUT.auth,
      intervals: [...E2E_POLL],
    })
    .toBe(true);

  return field;
}

export async function composeNewMessage(page: Page, peerUsername: string) {
  await ensureInboxReady(page);
  await page.getByRole('button', { name: 'Nuovo messaggio' }).click({
    timeout: E2E_TIMEOUT.ui,
  });
  const address = page.getByRole('textbox', { name: 'Indirizzo' });
  await address.fill(peerUsername);
  await page.getByRole('button', { name: 'Continua' }).click();
  await waitForChatInput(page);
}

function chatTextLocator(page: Page, body: string) {
  const token = body.match(/\d{8,}/)?.[0] ?? body;
  return page.locator('flt-semantics, [role="group"]').filter({ hasText: token });
}

export async function sendChatMessage(page: Page, body: string) {
  await expect(
    page.getByText(/cannot message yourself|messaggio a te stesso/i),
  ).not.toBeVisible({ timeout: 3_000 });
  const field = await waitForChatInput(page);
  await field.click();
  await page.waitForTimeout(150);
  await page.keyboard.type(body, { delay: 20 });
  await page.waitForTimeout(200);
  await page.keyboard.press('Enter');
  await expect(
    page.getByText(/cannot message yourself|PostgrestException/i),
  ).not.toBeVisible({ timeout: 3_000 });
  await expect(chatTextLocator(page, body).first()).toBeVisible({
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

/** Apre chat peer senza richiedere composer (es. allowlist mancante). */
export async function openPeerInInboxView(page: Page, displayName: string) {
  await expect(page.getByRole('button', { name: 'Nuovo messaggio' })).toBeVisible(
    { timeout: E2E_TIMEOUT.ui },
  );
  const row = inboxPeerButton(page, displayName);
  await expect(
    row.first(),
    `inbox senza conversazione con ${displayName}`,
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await row.first().click();
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole('button', { name: 'Altre azioni', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.auth });
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
    await expect(chatTextLocator(page, body).first()).toBeVisible({
      timeout: E2E_TIMEOUT.message,
    });
  }
  for (const body of options?.absent ?? []) {
    await expect(chatTextLocator(page, body)).not.toBeVisible({ timeout: 2_000 });
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
