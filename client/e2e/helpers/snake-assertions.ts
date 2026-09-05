// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Page } from '@playwright/test';

import { enableFlutterAccessibility } from './flutter-a11y';
import { formatDiagnosticLogsFooter } from './diagnostic-logs';
import { E2E_TIMEOUT } from './timeouts';

export async function expectNoChatSpinnerStuck(
  page: Page,
  context: string,
): Promise<void> {
  const spinnerStuck = await page
    .locator('flt-semantics')
    .filter({ hasText: /CircularProgressIndicator/i })
    .isVisible()
    .catch(() => false);
  expect(spinnerStuck, `${context}: chat non deve restare su spinner`).toBe(
    false,
  );
}

export async function expectRubricaShowsRemoveNotAdd(page: Page): Promise<void> {
  await expect(
    page.getByRole('button', { name: 'Rimuovi dalla rubrica', exact: true }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(
    page.getByRole('button', { name: 'Aggiungi alla rubrica', exact: true }),
  ).not.toBeVisible({ timeout: 2_000 });
}

/** Focus finale su gruppo: nav gruppo senza FAB inbox utente. */
export async function expectGroupAccountShell(page: Page): Promise<void> {
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole('button', { name: 'Persone consentite' }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await expect(
    page.getByRole('button', { name: 'Nuovo messaggio' }),
  ).not.toBeVisible({ timeout: 2_000 });
}

export function expectPushNavigationDiagnostics(diagLogs: string[]): void {
  expect(
    diagLogs.some(
      (line) =>
        line.includes('open_on_account.ok') ||
        line.includes('resolve_peer') ||
        line.includes('[nav]'),
    ),
    `percorso navigazione push atteso; ${formatDiagnosticLogsFooter(diagLogs)}`,
  ).toBe(true);
}

export async function expectChatHeaderShowsPeer(
  page: Page,
  peerDisplayName: string,
  stalePeerDisplayName: string,
): Promise<void> {
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        const headerShowsSender = await page
          .getByText(peerDisplayName)
          .first()
          .isVisible()
          .catch(() => false);
        const headerStillStale = await page
          .getByText(stalePeerDisplayName)
          .first()
          .isVisible()
          .catch(() => false);
        return headerShowsSender && !headerStillStale;
      },
      { timeout: E2E_TIMEOUT.message },
    )
    .toBe(true);
}
