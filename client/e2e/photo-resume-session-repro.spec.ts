// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * RIFERIMENTO — come si scrivono i test di release in Alfred.
 *
 * Copiare questo file per ogni nuovo scenario che l'utente fa sul telefono.
 * Documentazione: docs/testing/strategy.md § «Come si scrivono i test di release»
 * Hub: bash scripts/test.sh flusso-reale · tag @real-flow
 *
 * - Percorso utente completo (tap, drawer, chat, allegati, resume)
 * - Stack locale reale (supabase + Flutter release + Playwright)
 * - Login da UI, assert su Postgres (non solo canvas)
 * - Vietato: curl/JWT forzato, unit test Dart al posto di questo
 */
import { test, expect } from '@playwright/test';

import { expectImagePersistedBothSides } from './helpers/backend-assertions';
import { sendPhotoFromGalleryAfterPickerResume } from './helpers/chat-media';
import { enableFlutterAccessibility, readSavedAccountsManifest } from './helpers/flutter-a11y';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  prepareLocalFiveAccountManifest,
  setupFiveLocalAccounts,
} from './helpers/local-multi-account';
import {
  BASE_URL,
  closeDrawerIfOpen,
  composeNewMessage,
  manifestEntryForUsername,
  switchToAccountByDisplayName,
  waitForLoggedInShell,
} from './helpers/multi-account';
import {
  installPushTestEnvironment,
  waitForBrowserPushGranted,
} from './helpers/push';
import { configureLocalPushSettings } from './helpers/local-push-setup';
import { E2E_TIMEOUT } from './helpers/timeouts';

test.use({
  viewport: { width: 390, height: 844 },
  permissions: ['notifications'],
});
test.setTimeout(process.env.CI ? 600_000 : 300_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'solo stack locale');
  configureLocalPushSettings();
});

test.describe('@real-flow foto multi-account dopo galleria', () => {
test('4 user + gruppo: galleria dopo resume → foto in archivio (flusso telefono)', async ({
  page,
  context,
}) => {
  const stamp = `${Date.now()}`;
  const manifest = await prepareLocalFiveAccountManifest(stamp);
  const [user1, user2] = manifest.users;

  await page.goto(BASE_URL, {
    waitUntil: 'domcontentloaded',
    timeout: E2E_TIMEOUT.boot,
  });
  await installPushTestEnvironment(
    page,
    context,
    process.env.ALFRED_BASE_URL ?? 'http://localhost:8080/',
  );

  await setupFiveLocalAccounts(page, manifest);
  await closeDrawerIfOpen(page);

  const saved = (await readSavedAccountsManifest(page))!;
  const u2entry = manifestEntryForUsername(saved, user2.username);
  // Setup termina sul gruppo (no FAB): passa a user2 prima di push e compose.
  await switchToAccountByDisplayName(
    page,
    u2entry.displayName ?? `E2E u2${stamp}`,
    user2.userId,
  );
  await waitForLoggedInShell(page);
  await waitForBrowserPushGranted(page);

  await composeNewMessage(page, user1.username);

  await sendPhotoFromGalleryAfterPickerResume(page);

  await enableFlutterAccessibility(page);
  await expect(
    page.getByText(
      /StorageException|row-level security|Sessione scaduta|violates row-level security policy/i,
    ),
  ).not.toBeVisible({ timeout: 10_000 });
  await expect(
    page.getByRole('button', { name: /Riprova invio/i }),
  ).not.toBeVisible({ timeout: 5_000 });

  await expectImagePersistedBothSides({
    sender: {
      email: user2.email,
      password: user2.password,
      userId: user2.userId,
    },
    recipient: {
      email: user1.email,
      password: user1.password,
      userId: user1.userId,
    },
  });

  console.log('real_flow_OK — flusso utente completato, foto in archivio');
});
});
