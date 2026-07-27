// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Stesso flusso utente in produzione:
 * 4 user + 1 gruppo → focus account → chat → Allega → Galleria → resume → invio foto.
 * Verifica backend reale (messaggi + storage), nessun mock auth.
 */
import { test, expect } from '@playwright/test';

import { expectImagePersistedBothSides } from './helpers/backend-assertions';
import { sendPhotoFromGalleryAfterPickerResume } from './helpers/chat-media';
import { enableFlutterAccessibility } from './helpers/flutter-a11y';
import { isLocalSupabaseStack } from './helpers/local-auth';
import {
  prepareLocalFiveAccountManifest,
  setupFiveLocalAccounts,
} from './helpers/local-multi-account';
import {
  BASE_URL,
  composeNewMessage,
  switchToAccountByDisplayName,
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
test.setTimeout(300_000);

test.beforeAll(() => {
  test.skip(!isLocalSupabaseStack(), 'solo stack locale');
  configureLocalPushSettings();
});

test('4 user + gruppo: galleria dopo resume → foto inviata senza errore sessione', async ({
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
  await waitForBrowserPushGranted(page);

  await switchToAccountByDisplayName(
    page,
    `E2E u2${stamp}`,
    user2.userId,
  );
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

  console.log('photo_session_repro_OK — flusso utente completato, foto in archivio');
});
