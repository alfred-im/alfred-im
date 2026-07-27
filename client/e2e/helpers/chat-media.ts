// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import path from 'path';

import { expect, type Page } from '@playwright/test';

import { enableFlutterAccessibility } from './flutter-a11y';
import { waitForChatInput } from './multi-account';
import { E2E_TIMEOUT } from './timeouts';

const FIXTURE_IMAGE = path.resolve(__dirname, '../fixtures/test-photo.jpg');

/** PWA in background (picker OS / galleria aperta). */
export async function simulateAppBackground(page: Page) {
  const cdp = await page.context().newCDPSession(page);
  // Chromium headless: solo frozen/active (hidden → Protocol error).
  await cdp.send('Page.setWebLifecycleState', { state: 'frozen' });
  await page.waitForTimeout(400);
}

/** Ritorno in primo piano → Flutter AppLifecycleState.resumed → syncPushSubscriptions. */
export async function simulateAppResume(page: Page) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Page.setWebLifecycleState', { state: 'active' });
  await page.evaluate(() => {
    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('focus'));
  });
  // Tempo per sync push su tutti gli account del manifest (come produzione).
  await page.waitForTimeout(2500);
}

/** Allega → Galleria → background → file → resume → attende esito in chat. */
export async function sendPhotoFromGalleryAfterPickerResume(page: Page) {
  await waitForChatInput(page);
  await enableFlutterAccessibility(page);

  const fileChooserPromise = page.waitForEvent('filechooser', {
    timeout: E2E_TIMEOUT.ui,
  });
  await page.getByRole('button', { name: 'Allega' }).click({
    timeout: E2E_TIMEOUT.ui,
  });
  await page.getByRole('button', { name: 'Galleria foto' }).click({
    timeout: E2E_TIMEOUT.ui,
  });

  await simulateAppBackground(page);

  const fileChooser = await fileChooserPromise;
  await fileChooser.setFiles(FIXTURE_IMAGE);

  await simulateAppResume(page);
  await enableFlutterAccessibility(page);
}

/** Tap Allega → Galleria foto → file fixture; attende img in chat. */
export async function sendPhotoFromGallery(
  page: Page,
  options?: { caption?: string },
) {
  await waitForChatInput(page);
  await enableFlutterAccessibility(page);

  if (options?.caption) {
    const field = page
      .getByRole('textbox', { name: /Scrivi un messaggio/i })
      .or(page.locator('flt-semantics[role="textbox"]').last());
    await field.click();
    await field.fill(options.caption);
  }

  const fileChooserPromise = page.waitForEvent('filechooser', {
    timeout: E2E_TIMEOUT.ui,
  });
  await page.getByRole('button', { name: 'Allega' }).click({
    timeout: E2E_TIMEOUT.ui,
  });
  await page.getByRole('button', { name: 'Galleria foto' }).click({
    timeout: E2E_TIMEOUT.ui,
  });
  const fileChooser = await fileChooserPromise;
  await fileChooser.setFiles(FIXTURE_IMAGE);

  await expect(
    page.getByText(/PostgrestException|StorageException/i),
  ).not.toBeVisible({ timeout: 5_000 });

  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const networkImg = page.locator('img[src^="http"]');
        if ((await networkImg.count()) > 0) {
          for (let i = 0; i < (await networkImg.count()); i++) {
            if (await networkImg.nth(i).isVisible().catch(() => false)) {
              return true;
            }
          }
        }
        const imgs = page.locator('img');
        const count = await imgs.count();
        for (let i = 0; i < count; i++) {
          if (await imgs.nth(i).isVisible().catch(() => false)) return true;
        }
        return false;
      },
      { timeout: E2E_TIMEOUT.message * 3, intervals: [500, 1000, 2000] },
    )
    .toBe(true);

  await expect(
    page.locator('flt-semantics').filter({ hasText: /broken_image/i }),
  ).not.toBeVisible({ timeout: 2_000 });
}

/** Verifica che in chat ci sia almeno un'immagine renderizzata. */
export async function expectChatHasPhoto(page: Page) {
  await enableFlutterAccessibility(page);
  await expect
    .poll(
      async () => {
        const imgs = page.locator('img');
        const count = await imgs.count();
        for (let i = 0; i < count; i++) {
          if (await imgs.nth(i).isVisible().catch(() => false)) return true;
        }
        return false;
      },
      { timeout: E2E_TIMEOUT.message * 2, intervals: [500, 1000] },
    )
    .toBe(true);
}
