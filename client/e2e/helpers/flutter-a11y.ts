// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import type { Page } from '@playwright/test';

/** Abilita l'albero accessibilità Flutter web (necessario per getByRole/getByLabel). */
export async function enableFlutterAccessibility(page: Page) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const enabled = await page.evaluate(() => {
        const btn = document.querySelector(
          '[aria-label="Enable accessibility"]',
        ) as HTMLElement | null;
        if (!btn) return false;
        btn.click();
        return true;
      });
      if (enabled) {
        await page.waitForTimeout(400);
      }
      return;
    } catch {
      await page.waitForTimeout(300);
    }
  }
}

export type ManifestEntry = {
  userId: string;
  username?: string;
  displayName?: string;
  refreshToken: string;
};

export async function readSavedAccountsManifest(
  page: Page,
): Promise<ManifestEntry[] | null> {
  return page.evaluate(() => {
    const raw = localStorage.getItem('flutter.alfred_saved_accounts');
    if (!raw) return null;
    let data: unknown = JSON.parse(raw);
    while (typeof data === 'string') {
      data = JSON.parse(data);
    }
    return data as ManifestEntry[];
  });
}
